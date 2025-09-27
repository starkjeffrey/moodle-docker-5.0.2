#!/bin/bash

# Moodle 4.3.x Database Migration Helper Script
# This script helps restore your old Moodle database into the 4.3.x stack

set -e

echo "=================================================="
echo "Moodle 4.3.x Database Migration Helper"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if container is running
check_container() {
    if [ "$(docker ps -q -f name=$1)" ]; then
        return 0
    else
        return 1
    fi
}

# Function to wait for MariaDB to be ready
wait_for_mariadb() {
    echo "Waiting for MariaDB to be ready..."
    for i in {1..30}; do
        if docker exec moodle-4-3-mariadb mysqladmin ping -h localhost -u root -pmoodle_43_root_password --silent 2>/dev/null; then
            echo -e "${GREEN}MariaDB is ready!${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    echo -e "${RED}MariaDB failed to start within 60 seconds${NC}"
    return 1
}

# Step 1: Check if the backup file exists
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide the path to your database backup file${NC}"
    echo "Usage: $0 /path/to/backup.sql"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}Found backup file: $BACKUP_FILE${NC}"
echo ""

# Step 2: Start the Moodle 4.3.x stack
echo "Starting Moodle 4.3.x stack..."
docker compose -f docker-compose.moodle-4.3.yml up -d

# Wait for MariaDB to be ready
if ! wait_for_mariadb; then
    echo -e "${RED}Failed to start MariaDB. Please check the logs.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Choose migration option:${NC}"
echo "1) Restore database and let Moodle handle the upgrade (recommended)"
echo "2) Restore database as-is (manual upgrade required)"
echo -n "Enter choice [1-2]: "
read -r choice

case $choice in
    1)
        echo ""
        echo "Restoring database for automatic upgrade..."

        # Drop existing database and recreate
        echo "Preparing database..."
        docker exec moodle-4-3-mariadb mysql -u root -pmoodle_43_root_password -e "DROP DATABASE IF EXISTS bitnami_moodle_43;"
        docker exec moodle-4-3-mariadb mysql -u root -pmoodle_43_root_password -e "CREATE DATABASE bitnami_moodle_43 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

        # Import the backup
        echo "Importing backup (this may take several minutes)..."
        docker exec -i moodle-4-3-mariadb mysql -u bn_moodle_43 -pmoodle_43_db_password bitnami_moodle_43 < "$BACKUP_FILE"

        echo -e "${GREEN}Database restored successfully!${NC}"
        echo ""
        echo -e "${YELLOW}Important next steps:${NC}"
        echo "1. Access Moodle at: http://localhost:8081"
        echo "2. Moodle will detect the database needs upgrading"
        echo "3. Follow the on-screen upgrade instructions"
        echo "4. Default admin credentials (if not preserved from backup):"
        echo "   Username: admin"
        echo "   Password: Admin@43Migration"
        ;;

    2)
        echo ""
        echo "Restoring database as-is..."

        # Drop existing database and recreate
        echo "Preparing database..."
        docker exec moodle-4-3-mariadb mysql -u root -pmoodle_43_root_password -e "DROP DATABASE IF EXISTS bitnami_moodle_43;"
        docker exec moodle-4-3-mariadb mysql -u root -pmoodle_43_root_password -e "CREATE DATABASE bitnami_moodle_43 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

        # Import the backup
        echo "Importing backup (this may take several minutes)..."
        docker exec -i moodle-4-3-mariadb mysql -u bn_moodle_43 -pmoodle_43_db_password bitnami_moodle_43 < "$BACKUP_FILE"

        echo -e "${GREEN}Database restored successfully!${NC}"
        echo ""
        echo -e "${YELLOW}Manual steps required:${NC}"
        echo "1. Access container: docker exec -it moodle-4-3 /bin/bash"
        echo "2. Run upgrade: cd /bitnami/moodle && php admin/cli/upgrade.php"
        echo "3. Clear caches: php admin/cli/purge_caches.php"
        ;;

    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""
echo "=================================================="
echo "Migration process completed!"
echo "=================================================="
echo ""
echo "Useful commands:"
echo "- View logs: docker compose -f docker-compose.moodle-4.3.yml logs -f"
echo "- Stop stack: docker compose -f docker-compose.moodle-4.3.yml down"
echo "- Access database: docker exec -it moodle-4-3-mariadb mysql -u bn_moodle_43 -pmoodle_43_db_password bitnami_moodle_43"
echo ""
echo "Moodle 4.3.x URLs:"
echo "- HTTP: http://localhost:8081"
echo "- HTTPS: https://localhost:8444 (if SSL configured)"
echo "- Database: localhost:3307"
echo "- Redis: localhost:6380"