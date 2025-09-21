#!/bin/bash

# Master Control Script for All Moodle Environments
# Production, Legacy, and Test

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/Volumes/Projects/active/moodle-docker-5.0.2"
cd "$PROJECT_DIR"

# Function to display usage
usage() {
    echo "Usage: $0 {start|stop|restart|status|logs|backup} {prod|legacy|test|all}"
    echo ""
    echo "Commands:"
    echo "  start   - Start environment(s)"
    echo "  stop    - Stop environment(s)"
    echo "  restart - Restart environment(s)"
    echo "  status  - Show status of environment(s)"
    echo "  logs    - Show logs for environment(s)"
    echo "  backup  - Backup environment(s)"
    echo ""
    echo "Environments:"
    echo "  prod   - Production Moodle 5.0.2"
    echo "  legacy - Legacy Moodle 4.3.5"
    echo "  test   - Test Moodle 5.0.2"
    echo "  all    - All environments"
    echo ""
    echo "Examples:"
    echo "  $0 start prod      # Start production"
    echo "  $0 status all      # Show status of all environments"
    echo "  $0 logs test       # Show test environment logs"
    exit 1
}

# Function to start environment
start_env() {
    local env=$1
    case $env in
        prod)
            echo -e "${GREEN}Starting Production Moodle 5.0.2...${NC}"
            docker-compose -f docker-compose.moodle-hardened.yml up -d
            ;;
        legacy)
            echo -e "${YELLOW}Starting Legacy Moodle 4.3.5...${NC}"
            docker-compose -f docker-compose.moodle-legacy.yml up -d
            ;;
        test)
            echo -e "${BLUE}Starting Test Moodle 5.0.2...${NC}"
            docker-compose -f docker-compose.moodle-test.yml up -d
            ;;
        all)
            start_env prod
            start_env legacy
            start_env test
            ;;
        *)
            echo -e "${RED}Unknown environment: $env${NC}"
            usage
            ;;
    esac
}

# Function to stop environment
stop_env() {
    local env=$1
    case $env in
        prod)
            echo -e "${GREEN}Stopping Production Moodle...${NC}"
            docker-compose -f docker-compose.moodle-hardened.yml down
            ;;
        legacy)
            echo -e "${YELLOW}Stopping Legacy Moodle...${NC}"
            docker-compose -f docker-compose.moodle-legacy.yml down
            ;;
        test)
            echo -e "${BLUE}Stopping Test Moodle...${NC}"
            docker-compose -f docker-compose.moodle-test.yml down
            ;;
        all)
            stop_env prod
            stop_env legacy
            stop_env test
            ;;
        *)
            echo -e "${RED}Unknown environment: $env${NC}"
            usage
            ;;
    esac
}

# Function to show status
status_env() {
    local env=$1
    echo -e "${GREEN}=== Environment Status ===${NC}"
    echo ""

    case $env in
        prod|all)
            echo -e "${GREEN}Production Environment:${NC}"
            docker-compose -f docker-compose.moodle-hardened.yml ps
            echo ""
            ;;
    esac

    case $env in
        legacy|all)
            echo -e "${YELLOW}Legacy Environment:${NC}"
            docker-compose -f docker-compose.moodle-legacy.yml ps
            echo ""
            ;;
    esac

    case $env in
        test|all)
            echo -e "${BLUE}Test Environment:${NC}"
            docker-compose -f docker-compose.moodle-test.yml ps
            echo ""
            ;;
    esac

    if [[ "$env" != "prod" && "$env" != "legacy" && "$env" != "test" && "$env" != "all" ]]; then
        echo -e "${RED}Unknown environment: $env${NC}"
        usage
    fi
}

# Function to show logs
logs_env() {
    local env=$1
    case $env in
        prod)
            docker-compose -f docker-compose.moodle-hardened.yml logs -f
            ;;
        legacy)
            docker-compose -f docker-compose.moodle-legacy.yml logs -f
            ;;
        test)
            docker-compose -f docker-compose.moodle-test.yml logs -f
            ;;
        all)
            echo -e "${RED}Cannot tail logs for all environments simultaneously${NC}"
            echo "Please specify one environment"
            ;;
        *)
            echo -e "${RED}Unknown environment: $env${NC}"
            usage
            ;;
    esac
}

# Function to backup environment
backup_env() {
    local env=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)

    case $env in
        prod)
            echo -e "${GREEN}Backing up Production...${NC}"
            ./backup-system/scripts/backup-manager.sh backup full
            ;;
        legacy)
            echo -e "${YELLOW}Backing up Legacy...${NC}"
            docker exec moodle-mariadb-legacy mysqldump -u moodle_legacy -plegacy_pass_2023 moodle_legacy | \
                gzip > "backup_legacy_${timestamp}.sql.gz"
            echo "Legacy backup saved to backup_legacy_${timestamp}.sql.gz"
            ;;
        test)
            echo -e "${BLUE}Backing up Test...${NC}"
            docker exec moodle-mariadb-test mysqldump -u moodle_test -ptest_pass_2024 moodle_test | \
                gzip > "backup_test_${timestamp}.sql.gz"
            echo "Test backup saved to backup_test_${timestamp}.sql.gz"
            ;;
        all)
            backup_env prod
            backup_env legacy
            backup_env test
            ;;
        *)
            echo -e "${RED}Unknown environment: $env${NC}"
            usage
            ;;
    esac
}

# Function to restart environment
restart_env() {
    local env=$1
    stop_env $env
    sleep 2
    start_env $env
}

# Quick status check
quick_status() {
    echo -e "${GREEN}=== Quick Status Check ===${NC}"
    echo ""

    # Production
    if docker ps | grep -q moodle-app; then
        echo -e "Production: ${GREEN}✓ Running${NC} - http://localhost"
    else
        echo -e "Production: ${RED}✗ Stopped${NC}"
    fi

    # Legacy
    if docker ps | grep -q moodle-app-legacy; then
        echo -e "Legacy:     ${GREEN}✓ Running${NC} - http://localhost:8081"
    else
        echo -e "Legacy:     ${YELLOW}✗ Stopped${NC}"
    fi

    # Test
    if docker ps | grep -q moodle-app-test; then
        echo -e "Test:       ${GREEN}✓ Running${NC} - http://localhost:8082"
    else
        echo -e "Test:       ${BLUE}✗ Stopped${NC}"
    fi

    echo ""
}

# Main script logic
if [ $# -lt 1 ]; then
    quick_status
    echo ""
    usage
fi

COMMAND=$1
ENVIRONMENT=${2:-all}

case $COMMAND in
    start)
        start_env $ENVIRONMENT
        ;;
    stop)
        stop_env $ENVIRONMENT
        ;;
    restart)
        restart_env $ENVIRONMENT
        ;;
    status)
        status_env $ENVIRONMENT
        ;;
    logs)
        logs_env $ENVIRONMENT
        ;;
    backup)
        backup_env $ENVIRONMENT
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        usage
        ;;
esac

echo ""
echo -e "${GREEN}Operation complete!${NC}"