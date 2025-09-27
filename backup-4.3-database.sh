#!/bin/bash

# Backup script for Moodle 4.3.x database

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "Moodle 4.3.x Database Backup"
echo "=================================================="
echo ""

# Check if container is running
if [ ! "$(docker ps -q -f name=moodle-4-3-mariadb)" ]; then
    echo -e "${RED}Error: moodle-4-3-mariadb container is not running${NC}"
    echo "Start it with: docker compose -f docker-compose.moodle-4.3.yml up -d"
    exit 1
fi

# Create backups directory if it doesn't exist
mkdir -p backups/moodle-4.3

# Generate backup filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="backups/moodle-4.3/moodle_43_backup_${TIMESTAMP}.sql"

echo "Creating backup: $BACKUP_FILE"
echo "This may take several minutes depending on database size..."

# Perform the backup
docker exec moodle-4-3-mariadb mysqldump \
    -u bn_moodle_43 \
    -pmoodle_43_db_password \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-database \
    --databases bitnami_moodle_43 > "$BACKUP_FILE"

# Check if backup was successful
if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo "File: $BACKUP_FILE"
    echo "Size: $SIZE"

    # Compress the backup
    echo ""
    echo "Compressing backup..."
    gzip -k "$BACKUP_FILE"
    COMPRESSED_SIZE=$(ls -lh "${BACKUP_FILE}.gz" | awk '{print $5}')
    echo -e "${GREEN}Compressed backup created!${NC}"
    echo "File: ${BACKUP_FILE}.gz"
    echo "Size: $COMPRESSED_SIZE"
else
    echo -e "${RED}Backup failed! Please check the database connection.${NC}"
    exit 1
fi

echo ""
echo "=================================================="
echo "Backup completed!"
echo "=================================================="