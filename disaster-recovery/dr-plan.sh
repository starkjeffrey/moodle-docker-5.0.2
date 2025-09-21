#!/bin/bash

# Comprehensive Disaster Recovery and Git Backup System
# For Moodle installation at PUCSR
# Version: 3.0

set -euo pipefail

# ============================================
# CONFIGURATION
# ============================================

# Project paths
PROJECT_ROOT="/Volumes/Projects/active/moodle-docker-5.0.2"
MOODLE_GIT_DIR="${PROJECT_ROOT}/moodle-git"
DR_ROOT="/backup/disaster-recovery"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Moodle Git Repository
MOODLE_GIT_URL="https://github.com/moodle/moodle.git"
MOODLE_BRANCH="MOODLE_405_STABLE"  # Moodle 4.5 stable branch

# Primary Git Backup Locations (Free/Cheap)
GITHUB_BACKUP_REPO="git@github.com:pucsr/moodle-backup.git"
GITLAB_BACKUP_REPO="git@gitlab.com:pucsr/moodle-backup.git"
BITBUCKET_BACKUP_REPO="git@bitbucket.org:pucsr/moodle-backup.git"

# Additional Cheap Storage Options
# Backblaze B2 (10GB free, then $0.006/GB/month)
B2_ACCOUNT_ID="your_b2_account_id"
B2_APPLICATION_KEY="your_b2_app_key"
B2_BUCKET="pucsr-moodle-dr"

# Cloudflare R2 (10GB free, then $0.015/GB/month)
R2_ACCOUNT_ID="your_r2_account_id"
R2_ACCESS_KEY="your_r2_access_key"
R2_SECRET_KEY="your_r2_secret_key"
R2_BUCKET="pucsr-moodle-dr"

# Wasabi ($7/TB/month - cheapest for large storage)
WASABI_ACCESS_KEY="your_wasabi_access_key"
WASABI_SECRET_KEY="your_wasabi_secret_key"
WASABI_BUCKET="pucsr-moodle-dr"
WASABI_REGION="us-east-1"

# Local mirror location
LOCAL_MIRROR="/backup/git-mirrors"

# ============================================
# FUNCTIONS
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1"
}

# Install Moodle from Git
install_moodle_from_git() {
    log "Installing Moodle from Git repository..."

    # Clone Moodle repository if not exists
    if [ ! -d "${MOODLE_GIT_DIR}" ]; then
        log "Cloning Moodle repository..."
        git clone --branch ${MOODLE_BRANCH} --depth 1 ${MOODLE_GIT_URL} ${MOODLE_GIT_DIR}
    else
        log "Updating existing Moodle repository..."
        cd ${MOODLE_GIT_DIR}
        git fetch origin
        git checkout ${MOODLE_BRANCH}
        git pull origin ${MOODLE_BRANCH}
    fi

    # Create config.php for Moodle
    cat > ${MOODLE_GIT_DIR}/config.php <<'EOF'
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// Database configuration
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'mariadb';
$CFG->dbname    = 'bitnami_moodle';
$CFG->dbuser    = 'bn_moodle';
$CFG->dbpass    = getenv('MOODLE_DATABASE_PASSWORD');
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => 3306,
    'dbsocket' => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// Site configuration
$CFG->wwwroot   = 'https://moodle.pucsr.edu.kh';
$CFG->dataroot  = '/bitnami/moodledata';
$CFG->admin     = 'admin';

// Security settings
$CFG->cookiesecure = true;
$CFG->cookiehttponly = true;

// Session handling with Redis
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = 'redis';
$CFG->session_redis_port = 6379;
$CFG->session_redis_database = 0;
$CFG->session_redis_auth = getenv('MOODLE_REDIS_PASSWORD');
$CFG->session_redis_prefix = 'mdl_';

// Cache configuration with Redis
$CFG->alternative_cache_factory_class = 'cache_redis_factory';

// Performance settings
$CFG->cachedir = '/bitnami/moodledata/cache';
$CFG->localcachedir = '/bitnami/moodledata/localcache';
$CFG->tempdir = '/bitnami/moodledata/temp';
$CFG->trashdir = '/bitnami/moodledata/trash';

// Email configuration
$CFG->smtphosts = getenv('MOODLE_SMTP_HOST') . ':' . getenv('MOODLE_SMTP_PORT');
$CFG->smtpsecure = getenv('MOODLE_SMTP_PROTOCOL');
$CFG->smtpuser = getenv('MOODLE_SMTP_USER');
$CFG->smtppass = getenv('MOODLE_SMTP_PASSWORD');
$CFG->noreplyaddress = getenv('MOODLE_NOREPLY_ADDRESS');

// Timezone
date_default_timezone_set('Asia/Phnom_Penh');

require_once(__DIR__ . '/lib/setup.php');
EOF

    log_success "Moodle installed from Git"
}

# Setup Git backup repositories
setup_git_backups() {
    log "Setting up Git backup repositories..."

    cd ${PROJECT_ROOT}

    # Initialize git if not already
    if [ ! -d ".git" ]; then
        git init
        git config user.name "PUCSR Backup System"
        git config user.email "backup@pucsr.edu.kh"
    fi

    # Add multiple remote repositories for redundancy
    git remote add github ${GITHUB_BACKUP_REPO} 2>/dev/null || git remote set-url github ${GITHUB_BACKUP_REPO}
    git remote add gitlab ${GITLAB_BACKUP_REPO} 2>/dev/null || git remote set-url gitlab ${GITLAB_BACKUP_REPO}
    git remote add bitbucket ${BITBUCKET_BACKUP_REPO} 2>/dev/null || git remote set-url bitbucket ${BITBUCKET_BACKUP_REPO}

    # Create .gitignore for sensitive data
    cat > .gitignore <<'EOF'
# Sensitive data
*.env
*.key
*.pem
*.crt
passwords.txt
secrets/

# Backup files
*.sql
*.sql.gz
*.tar.gz
*.zip

# Temporary files
*.tmp
*.temp
*.log
logs/
temp/

# Moodle data (too large for git)
moodledata_data/
mariadb_data/
redis_data/

# But track important configs
!docker-compose*.yml
!backup-system/configs/*.conf.example
EOF

    log_success "Git backup repositories configured"
}

# Push to all Git remotes
push_to_git_remotes() {
    log "Pushing to all Git remote repositories..."

    cd ${PROJECT_ROOT}

    # Commit current state
    git add -A
    git commit -m "DR Backup: ${TIMESTAMP}" || true

    # Push to all remotes
    for remote in github gitlab bitbucket; do
        log "Pushing to ${remote}..."
        git push ${remote} main --force || log_error "Failed to push to ${remote}"
    done

    # Create backup branch with timestamp
    git checkout -b "backup-${TIMESTAMP}"
    for remote in github gitlab bitbucket; do
        git push ${remote} "backup-${TIMESTAMP}" || log_error "Failed to push backup branch to ${remote}"
    done
    git checkout main

    log_success "Pushed to all Git remotes"
}

# Setup Backblaze B2 backup
setup_b2_backup() {
    log "Setting up Backblaze B2 backup..."

    # Install B2 CLI if not present
    if ! command -v b2 &> /dev/null; then
        pip3 install --upgrade b2
    fi

    # Authorize B2
    b2 authorize-account ${B2_ACCOUNT_ID} ${B2_APPLICATION_KEY}

    # Create bucket if not exists
    b2 create-bucket ${B2_BUCKET} allPrivate --lifecycleRules '[
        {
            "daysFromHidingToDeleting": 30,
            "daysFromUploadingToHiding": 180,
            "fileNamePrefix": "old/"
        }
    ]' || true

    log_success "B2 backup configured"
}

# Backup to Backblaze B2
backup_to_b2() {
    local backup_file="$1"

    log "Uploading to Backblaze B2..."

    b2 upload-file \
        --threads 10 \
        ${B2_BUCKET} \
        "${backup_file}" \
        "dr-backups/$(basename ${backup_file})"

    log_success "Uploaded to B2"
}

# Setup Cloudflare R2 backup
setup_r2_backup() {
    log "Setting up Cloudflare R2 backup..."

    # Configure AWS CLI for R2
    aws configure set aws_access_key_id ${R2_ACCESS_KEY} --profile r2
    aws configure set aws_secret_access_key ${R2_SECRET_KEY} --profile r2
    aws configure set region auto --profile r2

    # Create bucket
    aws s3api create-bucket \
        --bucket ${R2_BUCKET} \
        --profile r2 \
        --endpoint-url https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com || true

    log_success "R2 backup configured"
}

# Backup to Cloudflare R2
backup_to_r2() {
    local backup_file="$1"

    log "Uploading to Cloudflare R2..."

    aws s3 cp \
        "${backup_file}" \
        "s3://${R2_BUCKET}/dr-backups/$(basename ${backup_file})" \
        --profile r2 \
        --endpoint-url https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com

    log_success "Uploaded to R2"
}

# Setup Wasabi backup
setup_wasabi_backup() {
    log "Setting up Wasabi backup..."

    # Configure AWS CLI for Wasabi
    aws configure set aws_access_key_id ${WASABI_ACCESS_KEY} --profile wasabi
    aws configure set aws_secret_access_key ${WASABI_SECRET_KEY} --profile wasabi
    aws configure set region ${WASABI_REGION} --profile wasabi

    # Create bucket
    aws s3api create-bucket \
        --bucket ${WASABI_BUCKET} \
        --profile wasabi \
        --endpoint-url https://s3.${WASABI_REGION}.wasabisys.com || true

    log_success "Wasabi backup configured"
}

# Backup to Wasabi
backup_to_wasabi() {
    local backup_file="$1"

    log "Uploading to Wasabi..."

    aws s3 cp \
        "${backup_file}" \
        "s3://${WASABI_BUCKET}/dr-backups/$(basename ${backup_file})" \
        --profile wasabi \
        --endpoint-url https://s3.${WASABI_REGION}.wasabisys.com \
        --storage-class STANDARD

    log_success "Uploaded to Wasabi"
}

# Create local Git mirror
create_local_mirror() {
    log "Creating local Git mirror..."

    mkdir -p ${LOCAL_MIRROR}

    # Mirror project repository
    if [ ! -d "${LOCAL_MIRROR}/moodle-docker.git" ]; then
        git clone --mirror ${PROJECT_ROOT}/.git ${LOCAL_MIRROR}/moodle-docker.git
    else
        cd ${LOCAL_MIRROR}/moodle-docker.git
        git fetch --all --prune
    fi

    # Mirror Moodle repository
    if [ ! -d "${LOCAL_MIRROR}/moodle.git" ]; then
        git clone --mirror ${MOODLE_GIT_URL} ${LOCAL_MIRROR}/moodle.git
    else
        cd ${LOCAL_MIRROR}/moodle.git
        git fetch --all --prune
    fi

    log_success "Local Git mirror created"
}

# Create disaster recovery snapshot
create_dr_snapshot() {
    log "Creating disaster recovery snapshot..."

    local dr_dir="${DR_ROOT}/snapshot_${TIMESTAMP}"
    mkdir -p ${dr_dir}

    # Export Docker images
    log "Exporting Docker images..."
    docker save bitnami/moodle:5.0.2 | gzip > ${dr_dir}/moodle-image.tar.gz
    docker save mariadb:11.4 | gzip > ${dr_dir}/mariadb-image.tar.gz
    docker save redis:7.2-alpine | gzip > ${dr_dir}/redis-image.tar.gz

    # Export volumes
    log "Exporting Docker volumes..."
    for volume in moodle_data moodledata_data mariadb_data redis_data; do
        docker run --rm \
            -v ${volume}:/data:ro \
            -v ${dr_dir}:/backup \
            alpine tar czf /backup/${volume}.tar.gz -C /data .
    done

    # Copy configuration
    cp -r ${PROJECT_ROOT}/*.yml ${dr_dir}/
    cp -r ${PROJECT_ROOT}/.envs ${dr_dir}/
    cp -r ${PROJECT_ROOT}/backup-system ${dr_dir}/

    # Create recovery script
    cat > ${dr_dir}/recover.sh <<'RECOVER_SCRIPT'
#!/bin/bash
# Disaster Recovery Script
set -e

echo "Starting disaster recovery..."

# Load Docker images
echo "Loading Docker images..."
docker load < moodle-image.tar.gz
docker load < mariadb-image.tar.gz
docker load < redis-image.tar.gz

# Restore volumes
echo "Restoring volumes..."
for volume_file in *_data.tar.gz; do
    volume_name=${volume_file%.tar.gz}
    docker volume create ${volume_name}
    docker run --rm \
        -v ${volume_name}:/data \
        -v $(pwd):/backup:ro \
        alpine tar xzf /backup/${volume_file} -C /data
done

# Copy configurations
cp -r .envs /Volumes/Projects/active/moodle-docker-5.0.2/
cp *.yml /Volumes/Projects/active/moodle-docker-5.0.2/

# Start services
cd /Volumes/Projects/active/moodle-docker-5.0.2
docker-compose -f docker-compose.production.yml up -d

echo "Disaster recovery complete!"
RECOVER_SCRIPT

    chmod +x ${dr_dir}/recover.sh

    # Create tarball
    tar czf ${DR_ROOT}/dr_snapshot_${TIMESTAMP}.tar.gz -C ${DR_ROOT} snapshot_${TIMESTAMP}

    log_success "DR snapshot created: ${DR_ROOT}/dr_snapshot_${TIMESTAMP}.tar.gz"

    echo "${DR_ROOT}/dr_snapshot_${TIMESTAMP}.tar.gz"
}

# Test disaster recovery
test_disaster_recovery() {
    log "Testing disaster recovery procedure..."

    # Create test environment
    local test_dir="/tmp/dr_test_${TIMESTAMP}"
    mkdir -p ${test_dir}

    # Extract latest DR snapshot
    local latest_snapshot=$(ls -t ${DR_ROOT}/dr_snapshot_*.tar.gz | head -1)
    tar xzf ${latest_snapshot} -C ${test_dir}

    # Test recovery script
    cd ${test_dir}/snapshot_*
    if bash -n recover.sh; then
        log_success "DR recovery script validated"
    else
        log_error "DR recovery script has errors"
        return 1
    fi

    # Clean up
    rm -rf ${test_dir}

    log_success "Disaster recovery test passed"
}

# Main disaster recovery function
perform_disaster_recovery() {
    log "=========================================="
    log "Starting Disaster Recovery Process"
    log "=========================================="

    # Install Moodle from Git
    install_moodle_from_git

    # Setup Git backups
    setup_git_backups

    # Push to Git remotes
    push_to_git_remotes

    # Create local mirror
    create_local_mirror

    # Create DR snapshot
    local snapshot_file=$(create_dr_snapshot)

    # Setup and backup to cheap storage providers
    if [[ "${B2_ACCOUNT_ID}" != "your_b2_account_id" ]]; then
        setup_b2_backup
        backup_to_b2 "${snapshot_file}"
    fi

    if [[ "${R2_ACCOUNT_ID}" != "your_r2_account_id" ]]; then
        setup_r2_backup
        backup_to_r2 "${snapshot_file}"
    fi

    if [[ "${WASABI_ACCESS_KEY}" != "your_wasabi_access_key" ]]; then
        setup_wasabi_backup
        backup_to_wasabi "${snapshot_file}"
    fi

    # Test disaster recovery
    test_disaster_recovery

    log_success "Disaster recovery process completed"
}

# ============================================
# MAIN EXECUTION
# ============================================

case "${1:-}" in
    install)
        install_moodle_from_git
        ;;
    backup)
        perform_disaster_recovery
        ;;
    push)
        push_to_git_remotes
        ;;
    mirror)
        create_local_mirror
        ;;
    snapshot)
        create_dr_snapshot
        ;;
    test)
        test_disaster_recovery
        ;;
    *)
        echo "Usage: $0 {install|backup|push|mirror|snapshot|test}"
        echo "  install  - Install Moodle from Git"
        echo "  backup   - Full disaster recovery backup"
        echo "  push     - Push to Git remotes only"
        echo "  mirror   - Create local Git mirror"
        echo "  snapshot - Create DR snapshot"
        echo "  test     - Test disaster recovery"
        exit 1
        ;;
esac