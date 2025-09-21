#!/bin/bash

# Comprehensive Restore Manager for Moodle Docker System
# Version: 2.0
# Features: Automated restoration, verification, rollback capability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../configs/backup.conf"
LOG_DIR="${SCRIPT_DIR}/../logs"
TEMP_DIR="${SCRIPT_DIR}/../temp"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/restore_${TIMESTAMP}.log"

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

# Create pre-restore backup
create_restore_point() {
    log "Creating restore point before restoration..."

    local restore_point_dir="${BACKUP_ROOT}/restore_points/rp_${TIMESTAMP}"
    mkdir -p "${restore_point_dir}"

    # Quick backup of current state
    docker exec moodle-mariadb mysqldump \
        --user="${DB_USER}" \
        --password="${DB_PASSWORD}" \
        --single-transaction \
        --all-databases | gzip > "${restore_point_dir}/pre_restore_db.sql.gz"

    # Save current container states
    docker ps -a --format json > "${restore_point_dir}/container_states.json"
    docker volume ls --format json > "${restore_point_dir}/volume_states.json"

    log_success "Restore point created: ${restore_point_dir}"
    echo "${restore_point_dir}"
}

# Download backup from remote storage
download_from_remote() {
    local backup_id="$1"
    local download_dir="${TEMP_DIR}/downloads"
    mkdir -p "${download_dir}"

    log "Downloading backup ${backup_id} from remote storage..."

    # Try S3 first
    if [[ "${ENABLE_S3_BACKUP}" == "true" ]]; then
        local s3_path="s3://${S3_BUCKET}/${S3_PREFIX}/${backup_id}"
        if aws s3 ls "${s3_path}" 2>/dev/null; then
            aws s3 cp "${s3_path}" "${download_dir}/${backup_id}"
            echo "${download_dir}/${backup_id}"
            return 0
        fi
    fi

    # Try Google Drive
    if [[ "${ENABLE_GDRIVE_BACKUP}" == "true" ]]; then
        # Use rclone for Google Drive operations
        if command -v rclone &> /dev/null; then
            rclone copy "gdrive:${GDRIVE_FOLDER_ID}/${backup_id}" "${download_dir}/"
            if [ -f "${download_dir}/${backup_id}" ]; then
                echo "${download_dir}/${backup_id}"
                return 0
            fi
        fi
    fi

    # Try Backblaze B2
    if [[ "${ENABLE_B2_BACKUP}" == "true" ]]; then
        b2 download-file-by-name "${B2_BUCKET_NAME}" "${backup_id}" "${download_dir}/${backup_id}"
        if [ -f "${download_dir}/${backup_id}" ]; then
            echo "${download_dir}/${backup_id}"
            return 0
        fi
    fi

    log_error "Could not download backup from any remote storage"
    return 1
}

# Extract and decrypt backup
extract_backup() {
    local backup_file="$1"
    local extract_dir="${TEMP_DIR}/restore_${TIMESTAMP}"
    mkdir -p "${extract_dir}"

    log "Extracting backup..."

    if [[ "${backup_file}" == *.enc ]]; then
        log "Decrypting backup..."
        openssl enc -aes-256-cbc -d -salt \
            -pass pass:"${ENCRYPTION_PASSWORD}" \
            -in "${backup_file}" | tar xzf - -C "${extract_dir}"
    else
        tar xzf "${backup_file}" -C "${extract_dir}"
    fi

    # Find the actual backup directory (it might be nested)
    local backup_content_dir=$(find "${extract_dir}" -maxdepth 2 -name "database" -type d | head -1 | xargs dirname)

    if [ -z "${backup_content_dir}" ]; then
        log_error "Invalid backup structure"
        return 1
    fi

    echo "${backup_content_dir}"
}

# Stop services
stop_services() {
    log "Stopping Moodle services..."

    # Stop containers gracefully
    docker-compose -f "${MOODLE_PROJECT_DIR}/docker-compose.moodle.yml" stop

    # Wait for containers to stop
    sleep 5

    log_success "Services stopped"
}

# Start services
start_services() {
    log "Starting Moodle services..."

    docker-compose -f "${MOODLE_PROJECT_DIR}/docker-compose.moodle.yml" up -d

    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker exec moodle-mariadb mysqladmin ping -h localhost -u root -p"${DB_PASSWORD}" &>/dev/null; then
            log_success "Services started and healthy"
            return 0
        fi
        sleep 10
        attempt=$((attempt + 1))
    done

    log_error "Services failed to start properly"
    return 1
}

# Restore MariaDB database
restore_mariadb() {
    local backup_dir="$1"

    log "Restoring MariaDB database..."

    # Find the database backup file
    local db_backup=""
    if [ -f "${backup_dir}/database/mariadb_full.sql.gz" ]; then
        db_backup="${backup_dir}/database/mariadb_full.sql.gz"
    elif [ -f "${backup_dir}/database/mariadb_full.sql" ]; then
        db_backup="${backup_dir}/database/mariadb_full.sql"
    else
        log_error "No database backup found"
        return 1
    fi

    # Restore database
    if [[ "${db_backup}" == *.gz ]]; then
        gunzip -c "${db_backup}" | docker exec -i moodle-mariadb mysql \
            -u root -p"${DB_PASSWORD}"
    else
        docker exec -i moodle-mariadb mysql \
            -u root -p"${DB_PASSWORD}" < "${db_backup}"
    fi

    # Verify database restoration
    local db_tables=$(docker exec moodle-mariadb mysql \
        -u "${DB_USER}" -p"${DB_PASSWORD}" \
        -e "USE ${DB_NAME}; SHOW TABLES;" | wc -l)

    if [ ${db_tables} -gt 1 ]; then
        log_success "Database restored: ${db_tables} tables found"
    else
        log_error "Database restoration may have failed"
        return 1
    fi
}

# Restore Docker volumes
restore_docker_volumes() {
    local backup_dir="$1"

    log "Restoring Docker volumes..."

    # Stop containers to safely restore volumes
    docker-compose -f "${MOODLE_PROJECT_DIR}/docker-compose.moodle.yml" stop

    for volume_archive in "${backup_dir}"/volumes/*.tar.gz; do
        if [ -f "${volume_archive}" ]; then
            local volume_name=$(basename "${volume_archive}" .tar.gz)
            log "Restoring volume: ${volume_name}"

            # Remove existing volume data
            docker volume rm "${volume_name}" 2>/dev/null || true
            docker volume create "${volume_name}"

            # Restore volume data
            docker run --rm \
                -v "${volume_name}:/restore" \
                -v "$(dirname "${volume_archive}"):/backup:ro" \
                alpine sh -c "cd /restore && tar xzf /backup/$(basename "${volume_archive}")"
        fi
    done

    log_success "Docker volumes restored"
}

# Restore Redis data
restore_redis() {
    local backup_dir="$1"

    if [ -f "${backup_dir}/database/redis_dump.rdb" ]; then
        log "Restoring Redis data..."

        # Copy dump file to Redis container
        docker cp "${backup_dir}/database/redis_dump.rdb" moodle-redis:/data/dump.rdb

        # Restart Redis to load the dump
        docker restart moodle-redis

        log_success "Redis data restored"
    fi
}

# Restore configuration files
restore_configs() {
    local backup_dir="$1"
    local restore_configs="${2:-false}"

    if [[ "${restore_configs}" == "true" ]]; then
        log "Restoring configuration files..."

        # Backup current configs
        cp -r "${MOODLE_PROJECT_DIR}/.envs" "${MOODLE_PROJECT_DIR}/.envs.bak.${TIMESTAMP}"

        # Restore configs
        cp -r "${backup_dir}/configs/.envs" "${MOODLE_PROJECT_DIR}/"

        # Restore docker-compose files if requested
        cp "${backup_dir}"/configs/*.yml "${MOODLE_PROJECT_DIR}/"

        log_success "Configuration files restored"
    else
        log "Skipping configuration restoration (use --restore-configs to enable)"
    fi
}

# Verify restoration
verify_restoration() {
    log "Verifying restoration..."

    local verification_passed=true
    local issues=()

    # Check if MariaDB is accessible
    if ! docker exec moodle-mariadb mysqladmin ping -h localhost -u root -p"${DB_PASSWORD}" &>/dev/null; then
        issues+=("MariaDB is not accessible")
        verification_passed=false
    fi

    # Check if Moodle is responding
    if ! curl -f -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
        issues+=("Moodle is not responding")
        verification_passed=false
    fi

    # Check volume integrity
    for volume in $(docker volume ls --format '{{.Name}}' | grep -E '^(moodle|mariadb)'); do
        if ! docker run --rm -v "${volume}:/check:ro" alpine ls /check &>/dev/null; then
            issues+=("Volume ${volume} is not accessible")
            verification_passed=false
        fi
    done

    if [ "${verification_passed}" = true ]; then
        log_success "Restoration verification passed"
        return 0
    else
        log_error "Restoration verification failed: ${issues[*]}"
        return 1
    fi
}

# Rollback restoration
rollback_restoration() {
    local restore_point="$1"

    log "Rolling back restoration..."

    # Stop services
    stop_services

    # Restore from restore point
    if [ -f "${restore_point}/pre_restore_db.sql.gz" ]; then
        start_services
        gunzip -c "${restore_point}/pre_restore_db.sql.gz" | \
            docker exec -i moodle-mariadb mysql -u root -p"${DB_PASSWORD}"
    fi

    log_success "Rollback completed"
}

# API sync for Naga SIS
sync_naga_sis() {
    log "Syncing with Naga SIS API..."

    # Check Moodle API connectivity
    local moodle_response=$(curl -s -X POST \
        "${MOODLE_API_URL}" \
        -d "wstoken=${MOODLE_API_TOKEN}" \
        -d "wsfunction=core_webservice_get_site_info" \
        -d "moodlewsrestformat=json")

    if echo "${moodle_response}" | jq -e '.sitename' &>/dev/null; then
        log "Moodle API connected successfully"

        # Trigger Naga SIS sync
        curl -s -X POST \
            "${NAGA_SIS_API_URL}/sync/moodle" \
            -H "Authorization: Bearer ${NAGA_SIS_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"action": "full_sync", "source": "restore"}'

        log_success "Naga SIS sync initiated"
    else
        log_error "Could not connect to Moodle API"
    fi
}

# Main restore function
perform_restore() {
    local backup_source="$1"
    local restore_options="$2"

    log "=========================================="
    log "Starting restore process"
    log "=========================================="

    # Create restore point
    local restore_point=$(create_restore_point)

    # Determine backup file location
    local backup_file=""
    if [ -f "${backup_source}" ]; then
        backup_file="${backup_source}"
    else
        # Try to download from remote
        backup_file=$(download_from_remote "${backup_source}")
    fi

    if [ -z "${backup_file}" ] || [ ! -f "${backup_file}" ]; then
        log_error "Backup file not found: ${backup_source}"
        exit 1
    fi

    # Extract backup
    local backup_dir=$(extract_backup "${backup_file}")

    # Stop services
    stop_services

    # Perform restoration
    restore_mariadb "${backup_dir}"
    restore_docker_volumes "${backup_dir}"
    restore_redis "${backup_dir}"
    restore_configs "${backup_dir}" "${RESTORE_CONFIGS:-false}"

    # Start services
    start_services

    # Verify restoration
    if verify_restoration; then
        log_success "Restoration completed successfully"

        # Sync with Naga SIS if configured
        if [[ "${ENABLE_NAGA_SIS_SYNC}" == "true" ]]; then
            sync_naga_sis
        fi

        # Clean up temporary files
        rm -rf "${backup_dir}"
        [ -f "${backup_file}" ] && rm "${backup_file}"
    else
        log_error "Restoration verification failed"
        read -p "Do you want to rollback? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rollback_restoration "${restore_point}"
        fi
        exit 1
    fi
}

# Parse command line arguments
case "${1:-}" in
    restore)
        perform_restore "${2}" "${3:-}"
        ;;
    rollback)
        rollback_restoration "${2}"
        ;;
    verify)
        verify_restoration
        ;;
    list)
        # List available backups
        echo "Local backups:"
        ls -la "${BACKUP_ROOT}"/*.tar.gz* 2>/dev/null || echo "No local backups found"
        echo ""
        echo "Remote backups (S3):"
        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" 2>/dev/null || echo "S3 not configured"
        ;;
    *)
        echo "Usage: $0 {restore|rollback|verify|list} [options]"
        echo "  restore <backup_file_or_id> [--restore-configs]"
        echo "  rollback <restore_point_dir>"
        echo "  verify"
        echo "  list"
        exit 1
        ;;
esac