#!/bin/bash
# Fix Moodle data permissions on container startup
echo "Fixing Moodle permissions..."
chown -R 1001:1001 /bitnami/moodledata 2>/dev/null || true
chmod -R 775 /bitnami/moodledata 2>/dev/null || true
echo "Moodle permissions fixed."