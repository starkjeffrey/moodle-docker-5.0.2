#!/bin/bash

echo "Starting full database restoration for Moodle 4.5..."
echo "This may take 10-15 minutes due to the large file size (1.6GB compressed)"
echo ""

# Function to monitor progress
monitor_progress() {
    while true; do
        TABLE_COUNT=$(docker exec moodle-4-5-mariadb mysql -u root -pmoodle_45_root_password -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='bitnami_moodle_45';" 2>/dev/null || echo "0")
        echo -ne "\rTables imported: $TABLE_COUNT"
        sleep 5

        # Check if restoration is complete (expecting more than 400 tables for a full Moodle database)
        if [ "$TABLE_COUNT" -gt 400 ]; then
            echo ""
            echo "Restoration appears complete with $TABLE_COUNT tables"
            break
        fi
    done
}

# Start the restoration in background
echo "Decompressing and importing database..."
gunzip -c data/tjm1PpXrZPcj.sql.gz | docker exec -i moodle-4-5-mariadb mysql -u bn_moodle_45 -pmoodle_45_db_password bitnami_moodle_45 2>/dev/null &
RESTORE_PID=$!

# Monitor progress
monitor_progress &
MONITOR_PID=$!

# Wait for restoration to complete
wait $RESTORE_PID
RESTORE_STATUS=$?

# Kill the monitor
kill $MONITOR_PID 2>/dev/null

echo ""
if [ $RESTORE_STATUS -eq 0 ]; then
    echo "✅ Database restoration completed successfully!"

    # Final table count
    FINAL_COUNT=$(docker exec moodle-4-5-mariadb mysql -u root -pmoodle_45_root_password -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='bitnami_moodle_45';" 2>/dev/null)
    echo "Total tables: $FINAL_COUNT"

    # Check for question tables
    echo ""
    echo "Checking for question bank tables..."
    docker exec moodle-4-5-mariadb mysql -u root -pmoodle_45_root_password -N -e "USE bitnami_moodle_45; SHOW TABLES;" 2>/dev/null | grep -i question | head -20
else
    echo "❌ Database restoration failed!"
fi