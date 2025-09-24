#!/bin/bash
set -e

echo "Fixing Moodle data directory permissions..."

# Fix ownership - ensure daemon user owns everything
chown -R daemon:daemon /bitnami/moodledata

# Fix directory permissions - 775 for directories
find /bitnami/moodledata -type d -exec chmod 775 {} \;

# Fix file permissions - 664 for files
find /bitnami/moodledata -type f -exec chmod 664 {} \;

echo "Permissions fixed successfully."