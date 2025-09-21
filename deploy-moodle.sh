#!/bin/bash

# Moodle Deployment Script for moodle.pucsr.edu.kh
# Pannasastra University of Cambodia - Siem Reap Campus

set -euo pipefail

# Configuration
DOMAIN="moodle.pucsr.edu.kh"
PROJECT_DIR="/Volumes/Projects/active/moodle-docker-5.0.2"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Setup directories
setup_directories() {
    log_info "Setting up directories..."

    mkdir -p ${PROJECT_DIR}/{volumes,traefik/letsencrypt,traefik/config,backup-system/logs,disaster-recovery}
    mkdir -p /backup/moodle/{daily,weekly,monthly,restore_points}

    # Set permissions
    chmod 755 ${PROJECT_DIR}/backup-system/scripts/*.sh 2>/dev/null || true
    chmod 755 ${PROJECT_DIR}/disaster-recovery/*.sh 2>/dev/null || true

    log_info "Directories created"
}

# Install Moodle from Git
install_moodle_git() {
    log_info "Installing Moodle from Git repository..."

    cd ${PROJECT_DIR}

    # Check if we should use Git-based Moodle
    if [ ! -d "moodle-git" ]; then
        log_info "Cloning Moodle repository (this may take a while)..."
        git clone --branch MOODLE_405_STABLE --depth 1 https://github.com/moodle/moodle.git moodle-git

        # Install additional plugins from Git if needed
        log_info "Installing additional Moodle plugins..."

        # Example: Installing popular plugins
        # git clone https://github.com/moodlehq/moodle-local_mobile.git moodle-git/local/mobile
        # git clone https://github.com/danmarsden/moodle-mod_attendance.git moodle-git/mod/attendance
    else
        log_info "Updating existing Moodle Git repository..."
        cd moodle-git
        git fetch origin
        git pull origin MOODLE_405_STABLE
        cd ..
    fi

    log_info "Moodle Git installation complete"
}

# Configure environment
configure_environment() {
    log_info "Configuring environment..."

    # Backup existing env files
    if [ -f "${PROJECT_DIR}/.envs/.moodle/moodle.env" ]; then
        cp ${PROJECT_DIR}/.envs/.moodle/moodle.env ${PROJECT_DIR}/.envs/.moodle/moodle.env.bak.${TIMESTAMP}
    fi

    # Use production environment
    cp ${PROJECT_DIR}/.envs/.moodle/moodle-production.env ${PROJECT_DIR}/.envs/.moodle/moodle.env

    # Generate secure passwords if not set
    if grep -q "change_me" ${PROJECT_DIR}/.envs/.moodle/moodle.env; then
        log_warn "Generating secure passwords..."

        # Generate random passwords
        DB_PASSWORD=$(openssl rand -base64 32)
        REDIS_PASSWORD=$(openssl rand -base64 32)
        ADMIN_PASSWORD=$(openssl rand -base64 16)

        # Update env file
        sed -i.bak "s/secure_password_change_me_now/${DB_PASSWORD}/" ${PROJECT_DIR}/.envs/.moodle/moodle.env
        sed -i.bak "s/redis_secure_password/${REDIS_PASSWORD}/" ${PROJECT_DIR}/.envs/.moodle/moodle.env
        sed -i.bak "s/PUCSRadmin@2024!/${ADMIN_PASSWORD}/" ${PROJECT_DIR}/.envs/.moodle/moodle.env

        # Save passwords securely
        cat > ${PROJECT_DIR}/.passwords.txt <<EOF
MOODLE CREDENTIALS - KEEP SECURE!
Generated: ${TIMESTAMP}
================================
Database Password: ${DB_PASSWORD}
Redis Password: ${REDIS_PASSWORD}
Admin Password: ${ADMIN_PASSWORD}
Admin URL: https://${DOMAIN}/admin
EOF
        chmod 600 ${PROJECT_DIR}/.passwords.txt

        log_warn "Passwords saved to .passwords.txt - KEEP THIS FILE SECURE!"
    fi

    log_info "Environment configured"
}

# Setup SSL certificates
setup_ssl() {
    log_info "Setting up SSL certificates..."

    # Create self-signed certificate for initial setup
    if [ ! -f "${PROJECT_DIR}/traefik/letsencrypt/acme.json" ]; then
        touch ${PROJECT_DIR}/traefik/letsencrypt/acme.json
        chmod 600 ${PROJECT_DIR}/traefik/letsencrypt/acme.json
    fi

    log_info "SSL setup complete - Let's Encrypt will auto-provision certificates"
}

# Setup disaster recovery
setup_disaster_recovery() {
    log_info "Setting up disaster recovery with Git backups..."

    cd ${PROJECT_DIR}

    # Initialize Git repository
    if [ ! -d ".git" ]; then
        git init
        git config user.name "PUCSR Moodle Admin"
        git config user.email "it@pucsr.edu.kh"

        # Create initial commit
        git add -A
        git commit -m "Initial Moodle deployment for ${DOMAIN}" || true
    fi

    # Setup cron jobs for automated backups
    log_info "Setting up automated backup schedule..."

    # Create cron job for daily backups
    cat > /tmp/moodle-cron <<EOF
# Moodle Backup Schedule
# Daily backup at 2 AM
0 2 * * * ${PROJECT_DIR}/backup-system/scripts/backup-manager.sh backup daily >> ${PROJECT_DIR}/backup-system/logs/cron.log 2>&1

# Weekly backup on Sunday at 3 AM
0 3 * * 0 ${PROJECT_DIR}/backup-system/scripts/backup-manager.sh backup weekly >> ${PROJECT_DIR}/backup-system/logs/cron.log 2>&1

# Monthly backup on 1st at 4 AM
0 4 1 * * ${PROJECT_DIR}/backup-system/scripts/backup-manager.sh backup monthly >> ${PROJECT_DIR}/backup-system/logs/cron.log 2>&1

# Disaster recovery push to Git daily at 5 AM
0 5 * * * ${PROJECT_DIR}/disaster-recovery/dr-plan.sh push >> ${PROJECT_DIR}/disaster-recovery/dr.log 2>&1

# Verify backups daily at noon
0 12 * * * ${PROJECT_DIR}/backup-system/scripts/backup-manager.sh verify >> ${PROJECT_DIR}/backup-system/logs/verify.log 2>&1
EOF

    # Install cron jobs
    crontab -l 2>/dev/null | grep -v "moodle-docker" > /tmp/current-cron || true
    cat /tmp/moodle-cron >> /tmp/current-cron
    crontab /tmp/current-cron
    rm /tmp/moodle-cron /tmp/current-cron

    log_info "Disaster recovery configured"
}

# Start services
start_services() {
    log_info "Starting Moodle services..."

    cd ${PROJECT_DIR}

    # Stop any existing services
    docker-compose -f docker-compose.production.yml down 2>/dev/null || true

    # Start services
    docker-compose -f docker-compose.production.yml up -d

    log_info "Waiting for services to be ready..."
    sleep 30

    # Check service health
    if docker ps | grep -q moodle-app; then
        log_info "Moodle container is running"
    else
        log_error "Moodle container failed to start"
        docker-compose -f docker-compose.production.yml logs moodle
        exit 1
    fi

    if docker ps | grep -q moodle-mariadb; then
        log_info "MariaDB container is running"
    else
        log_error "MariaDB container failed to start"
        docker-compose -f docker-compose.production.yml logs mariadb
        exit 1
    fi

    log_info "Services started successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."

    # Check if Moodle is responding
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -k -f -s -o /dev/null -w "%{http_code}" https://localhost | grep -q "200\|301\|302"; then
            log_info "Moodle is responding"
            break
        fi
        log_warn "Waiting for Moodle to respond... (attempt ${attempt}/${max_attempts})"
        sleep 10
        attempt=$((attempt + 1))
    done

    if [ $attempt -gt $max_attempts ]; then
        log_error "Moodle failed to respond after ${max_attempts} attempts"
        exit 1
    fi

    # Display access information
    echo ""
    echo "=========================================="
    echo -e "${GREEN}MOODLE DEPLOYMENT SUCCESSFUL!${NC}"
    echo "=========================================="
    echo ""
    echo "Access URLs:"
    echo "  Main Site: https://${DOMAIN}"
    echo "  Admin Panel: https://${DOMAIN}/admin"
    echo ""

    if [ -f "${PROJECT_DIR}/.passwords.txt" ]; then
        echo "Credentials saved in: ${PROJECT_DIR}/.passwords.txt"
        echo ""
        cat ${PROJECT_DIR}/.passwords.txt
    fi

    echo ""
    echo "Next Steps:"
    echo "1. Configure DNS to point ${DOMAIN} to this server"
    echo "2. Wait for SSL certificates to be provisioned (may take a few minutes)"
    echo "3. Access the site and complete initial setup"
    echo "4. Configure Naga SIS integration via Admin > Plugins"
    echo ""
    echo "Useful Commands:"
    echo "  View logs: docker-compose -f docker-compose.production.yml logs -f"
    echo "  Stop services: docker-compose -f docker-compose.production.yml down"
    echo "  Backup now: ./backup-system/scripts/backup-manager.sh backup full"
    echo "  Check status: docker ps"
    echo ""
}

# Main deployment process
main() {
    echo "=========================================="
    echo "MOODLE DEPLOYMENT FOR ${DOMAIN}"
    echo "=========================================="
    echo ""

    check_prerequisites
    setup_directories
    install_moodle_git
    configure_environment
    setup_ssl
    setup_disaster_recovery
    start_services
    verify_deployment

    log_info "Deployment complete!"
}

# Run main function
main