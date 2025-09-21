#!/bin/bash

# Comprehensive Backup Manager for Moodle Docker System
# Version: 2.0
# Features: Automated backups, verification, rotation, and recovery

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../configs/backup.conf"
LOG_DIR="${SCRIPT_DIR}/../logs"
TEMP_DIR="${SCRIPT_DIR}/../temp"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# Load configuration
source "${CONFIG_FILE}"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "${LOG_FILE}" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "${LOG_FILE}"
}

# Notification function
send_notification() {
    local subject="$1"
    local message="$2"
    local priority="${3:-INFO}"

    # Email notification if configured
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS}" == "true" ]]; then
        echo "${message}" | mail -s "[${priority}] Backup System: ${subject}" "${ADMIN_EMAIL}"
    fi

    # Slack notification if configured
    if [[ "${ENABLE_SLACK_NOTIFICATIONS}" == "true" && -n "${SLACK_WEBHOOK_URL}" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"[${priority}] ${subject}\n${message}\"}" \
            "${SLACK_WEBHOOK_URL}" 2>/dev/null || true
    fi

    # System log
    logger -t "backup-manager" -p "user.${priority,,}" "${subject}: ${message}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    local missing_tools=()
    for tool in docker rsync tar gzip openssl mysql pg_dump redis-cli jq; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi

    # Check disk space
    local available_space=$(df -BG "${BACKUP_ROOT}" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${available_space}" -lt "${MIN_DISK_SPACE_GB}" ]; then
        log_error "Insufficient disk space. Available: ${available_space}GB, Required: ${MIN_DISK_SPACE_GB}GB"
        return 1
    fi

    log_success "Prerequisites check passed"
    return 0
}

# Create backup directory structure
create_backup_structure() {
    local backup_dir="${BACKUP_ROOT}/${BACKUP_TYPE}_${TIMESTAMP}"
    mkdir -p "${backup_dir}"/{database,volumes,configs,metadata}
    echo "${backup_dir}"
}

# Backup Docker volumes
backup_docker_volumes() {
    local backup_dir="$1"
    log "Starting Docker volume backup..."

    # Get list of Moodle-related volumes
    local volumes=$(docker volume ls --format '{{.Name}}' | grep -E '^(moodle|mariadb|redis)')

    for volume in ${volumes}; do
        log "Backing up volume: ${volume}"

        # Create temporary container to access volume
        docker run --rm \
            -v "${volume}:/source:ro" \
            -v "${backup_dir}/volumes:/backup" \
            alpine tar czf "/backup/${volume}.tar.gz" -C /source .

        # Calculate checksum
        sha256sum "${backup_dir}/volumes/${volume}.tar.gz" > \
            "${backup_dir}/volumes/${volume}.tar.gz.sha256"
    done

    log_success "Docker volumes backup completed"
}

# Backup MariaDB database
backup_mariadb() {
    local backup_dir="$1"
    log "Starting MariaDB backup..."

    # Check if container is running
    if ! docker ps | grep -q moodle-mariadb; then
        log_error "MariaDB container is not running"
        return 1
    fi

    # Perform database dump with multiple formats
    # Standard SQL dump
    docker exec moodle-mariadb mysqldump \
        --user="${DB_USER}" \
        --password="${DB_PASSWORD}" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --all-databases \
        --add-drop-database \
        > "${backup_dir}/database/mariadb_full.sql"

    # Compress the dump
    gzip -9 "${backup_dir}/database/mariadb_full.sql"

    # Create schema-only backup
    docker exec moodle-mariadb mysqldump \
        --user="${DB_USER}" \
        --password="${DB_PASSWORD}" \
        --no-data \
        --routines \
        --triggers \
        --events \
        --all-databases \
        > "${backup_dir}/database/mariadb_schema.sql"

    # Binary backup using mariabackup (if available)
    if docker exec moodle-mariadb which mariabackup &>/dev/null; then
        log "Creating binary backup with mariabackup..."
        docker exec moodle-mariadb mariabackup \
            --backup \
            --target-dir=/backup \
            --user="${DB_USER}" \
            --password="${DB_PASSWORD}"

        docker cp moodle-mariadb:/backup "${backup_dir}/database/mariabackup"
    fi

    # Generate checksums
    find "${backup_dir}/database" -type f -exec sha256sum {} \; > \
        "${backup_dir}/database/checksums.sha256"

    log_success "MariaDB backup completed"
}

# Backup Redis data (if using hardened setup)
backup_redis() {
    local backup_dir="$1"

    if docker ps | grep -q moodle-redis; then
        log "Starting Redis backup..."

        # Trigger Redis BGSAVE
        docker exec moodle-redis redis-cli --pass "${REDIS_PASSWORD}" BGSAVE

        # Wait for background save to complete
        while [ $(docker exec moodle-redis redis-cli --pass "${REDIS_PASSWORD}" LASTSAVE) -eq \
                $(docker exec moodle-redis redis-cli --pass "${REDIS_PASSWORD}" LASTSAVE) ]; do
            sleep 1
        done

        # Copy dump file
        docker cp moodle-redis:/data/dump.rdb "${backup_dir}/database/redis_dump.rdb"

        # Also export Redis data as JSON for portability
        docker exec moodle-redis redis-cli --pass "${REDIS_PASSWORD}" \
            --rdb /data/dump.rdb --json > "${backup_dir}/database/redis_data.json"

        log_success "Redis backup completed"
    fi
}

# Backup configuration files
backup_configs() {
    local backup_dir="$1"
    log "Backing up configuration files..."

    # Copy docker-compose files
    cp -r "${MOODLE_PROJECT_DIR}"/*.yml "${backup_dir}/configs/"

    # Copy environment files
    cp -r "${MOODLE_PROJECT_DIR}/.envs" "${backup_dir}/configs/"

    # Copy any custom configurations
    if [ -d "${MOODLE_PROJECT_DIR}/custom" ]; then
        cp -r "${MOODLE_PROJECT_DIR}/custom" "${backup_dir}/configs/"
    fi

    # Remove any sensitive data from configs if needed
    find "${backup_dir}/configs" -type f -name "*.env" -exec \
        sed -i 's/PASSWORD=.*/PASSWORD=REDACTED/g' {} \;

    log_success "Configuration backup completed"
}

# Create backup metadata
create_metadata() {
    local backup_dir="$1"
    local start_time="$2"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    cat > "${backup_dir}/metadata/backup_info.json" <<EOF
{
    "backup_id": "${TIMESTAMP}",
    "backup_type": "${BACKUP_TYPE}",
    "backup_date": "$(date -Iseconds)",
    "backup_duration_seconds": ${duration},
    "docker_version": "$(docker --version)",
    "compose_version": "$(docker compose version)",
    "system_info": {
        "hostname": "$(hostname)",
        "os": "$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)"
    },
    "moodle_info": {
        "version": "5.0.2",
        "volumes": $(docker volume ls --format '{{.Name}}' | grep -E '^(moodle|mariadb|redis)' | jq -R . | jq -s .),
        "containers": $(docker ps --format '{{.Names}}' | grep -E '^(moodle|mariadb|redis)' | jq -R . | jq -s .)
    },
    "backup_size_bytes": $(du -sb "${backup_dir}" | cut -f1),
    "verification_status": "pending"
}
EOF

    log "Metadata created"
}

# Encrypt backup if configured
encrypt_backup() {
    local backup_dir="$1"

    if [[ "${ENABLE_ENCRYPTION}" == "true" ]]; then
        log "Encrypting backup..."

        tar czf - -C "$(dirname "${backup_dir}")" "$(basename "${backup_dir}")" | \
            openssl enc -aes-256-cbc -salt -pass pass:"${ENCRYPTION_PASSWORD}" \
            > "${backup_dir}.tar.gz.enc"

        # Generate encryption metadata
        echo "{
            \"encrypted\": true,
            \"algorithm\": \"aes-256-cbc\",
            \"timestamp\": \"$(date -Iseconds)\"
        }" > "${backup_dir}.tar.gz.enc.meta"

        # Remove unencrypted backup
        rm -rf "${backup_dir}"

        log_success "Backup encrypted successfully"
        return 0
    fi

    # Create compressed archive even if not encrypting
    tar czf "${backup_dir}.tar.gz" -C "$(dirname "${backup_dir}")" "$(basename "${backup_dir}")"
    rm -rf "${backup_dir}"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    log "Verifying backup integrity..."

    local verification_passed=true
    local issues=()

    # Check if backup file exists and has size > 0
    if [ ! -f "${backup_file}" ]; then
        issues+=("Backup file not found")
        verification_passed=false
    elif [ ! -s "${backup_file}" ]; then
        issues+=("Backup file is empty")
        verification_passed=false
    fi

    # Try to list contents of archive
    if [[ "${backup_file}" == *.enc ]]; then
        # Verify encrypted backup
        if ! openssl enc -aes-256-cbc -d -salt -pass pass:"${ENCRYPTION_PASSWORD}" \
            -in "${backup_file}" 2>/dev/null | tar tzf - &>/dev/null; then
            issues+=("Cannot decrypt or read encrypted backup")
            verification_passed=false
        fi
    else
        # Verify regular backup
        if ! tar tzf "${backup_file}" &>/dev/null; then
            issues+=("Cannot read backup archive")
            verification_passed=false
        fi
    fi

    if [ "${verification_passed}" = true ]; then
        log_success "Backup verification passed"

        # Update metadata with verification status
        local meta_file="${backup_file%.tar.gz*}/metadata/backup_info.json"
        if [ -f "${meta_file}" ]; then
            jq '.verification_status = "passed" | .verification_date = now | .verification_issues = []' \
                "${meta_file}" > "${meta_file}.tmp" && mv "${meta_file}.tmp" "${meta_file}"
        fi

        return 0
    else
        log_error "Backup verification failed: ${issues[*]}"
        send_notification "Backup Verification Failed" \
            "Issues found: ${issues[*]}" "ERROR"
        return 1
    fi
}

# Upload to remote storage
upload_to_remote() {
    local backup_file="$1"

    if [[ "${ENABLE_REMOTE_BACKUP}" != "true" ]]; then
        return 0
    fi

    log "Uploading to remote storage..."

    case "${REMOTE_STORAGE_TYPE}" in
        "s3")
            aws s3 cp "${backup_file}" "s3://${S3_BUCKET}/${S3_PREFIX}/$(basename "${backup_file}")" \
                --storage-class "${S3_STORAGE_CLASS:-STANDARD_IA}"
            ;;
        "rsync")
            rsync -avz --progress "${backup_file}" \
                "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH}/$(basename "${backup_file}")"
            ;;
        "scp")
            scp "${backup_file}" \
                "${SCP_USER}@${SCP_HOST}:${SCP_PATH}/$(basename "${backup_file}")"
            ;;
        *)
            log_error "Unknown remote storage type: ${REMOTE_STORAGE_TYPE}"
            return 1
            ;;
    esac

    log_success "Remote upload completed"
}

# Cleanup old backups based on retention policy
cleanup_old_backups() {
    log "Cleaning up old backups based on retention policy..."

    # Keep daily backups for N days
    find "${BACKUP_ROOT}" -name "*daily*.tar.gz*" -mtime +${DAILY_RETENTION_DAYS} -delete

    # Keep weekly backups for N weeks
    find "${BACKUP_ROOT}" -name "*weekly*.tar.gz*" -mtime +$((WEEKLY_RETENTION_WEEKS * 7)) -delete

    # Keep monthly backups for N months
    find "${BACKUP_ROOT}" -name "*monthly*.tar.gz*" -mtime +$((MONTHLY_RETENTION_MONTHS * 30)) -delete

    # Clean up old logs
    find "${LOG_DIR}" -name "*.log" -mtime +30 -delete

    log_success "Cleanup completed"
}

# Test restore capability
test_restore() {
    local backup_file="$1"
    log "Testing restore capability..."

    local test_dir="${TEMP_DIR}/restore_test_${TIMESTAMP}"
    mkdir -p "${test_dir}"

    # Extract backup to test directory
    if [[ "${backup_file}" == *.enc ]]; then
        openssl enc -aes-256-cbc -d -salt -pass pass:"${ENCRYPTION_PASSWORD}" \
            -in "${backup_file}" | tar xzf - -C "${test_dir}"
    else
        tar xzf "${backup_file}" -C "${test_dir}"
    fi

    # Verify critical files exist
    local restore_valid=true
    local required_dirs=("database" "volumes" "configs" "metadata")

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${test_dir}"/*/"${dir}" ]; then
            log_error "Missing required directory in backup: ${dir}"
            restore_valid=false
        fi
    done

    # Clean up test directory
    rm -rf "${test_dir}"

    if [ "${restore_valid}" = true ]; then
        log_success "Restore test passed"
        return 0
    else
        log_error "Restore test failed"
        return 1
    fi
}

# Main backup function
perform_backup() {
    local start_time=$(date +%s)

    log "=========================================="
    log "Starting ${BACKUP_TYPE} backup process"
    log "=========================================="

    # Check prerequisites
    if ! check_prerequisites; then
        send_notification "Backup Failed" "Prerequisites check failed" "ERROR"
        exit 1
    fi

    # Create backup directory structure
    local backup_dir=$(create_backup_structure)

    # Perform backups
    backup_docker_volumes "${backup_dir}"
    backup_mariadb "${backup_dir}"
    backup_redis "${backup_dir}"
    backup_configs "${backup_dir}"

    # Create metadata
    create_metadata "${backup_dir}" "${start_time}"

    # Encrypt backup if configured
    encrypt_backup "${backup_dir}"

    # Determine final backup file name
    local backup_file
    if [[ "${ENABLE_ENCRYPTION}" == "true" ]]; then
        backup_file="${backup_dir}.tar.gz.enc"
    else
        backup_file="${backup_dir}.tar.gz"
    fi

    # Verify backup
    if verify_backup "${backup_file}"; then
        # Test restore capability
        if [[ "${TEST_RESTORE}" == "true" ]]; then
            test_restore "${backup_file}"
        fi

        # Upload to remote storage
        upload_to_remote "${backup_file}"

        # Cleanup old backups
        cleanup_old_backups

        # Calculate backup size
        local backup_size=$(du -sh "${backup_file}" | cut -f1)

        log_success "Backup completed successfully"
        log "Backup file: ${backup_file}"
        log "Backup size: ${backup_size}"

        send_notification "Backup Completed" \
            "Type: ${BACKUP_TYPE}\nFile: ${backup_file}\nSize: ${backup_size}" \
            "INFO"
    else
        send_notification "Backup Failed" \
            "Verification failed for ${backup_file}" \
            "ERROR"
        exit 1
    fi
}

# Parse command line arguments
case "${1:-}" in
    backup)
        BACKUP_TYPE="${2:-full}"
        perform_backup
        ;;
    verify)
        verify_backup "${2}"
        ;;
    restore)
        echo "Use restore-manager.sh for restore operations"
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    test)
        test_restore "${2}"
        ;;
    *)
        echo "Usage: $0 {backup|verify|cleanup|test} [options]"
        echo "  backup [full|incremental|daily|weekly|monthly]"
        echo "  verify <backup_file>"
        echo "  cleanup"
        echo "  test <backup_file>"
        exit 1
        ;;
esac