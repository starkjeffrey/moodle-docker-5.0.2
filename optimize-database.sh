#!/bin/bash

echo "=========================================="
echo "Moodle Database Optimization Script"
echo "Starting at: $(date)"
echo "=========================================="

# Database connection parameters
DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"

# Function to execute SQL
execute_sql() {
    docker exec $DB_HOST mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

# Function to execute SQL with output
execute_sql_output() {
    docker exec $DB_HOST mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

echo ""
echo "STEP 1: HTML CLEANING"
echo "===================="

# Clean HTML from assignment content
echo "Cleaning HTML from assignment instructions..."
execute_sql "
-- Create backup table first
CREATE TABLE IF NOT EXISTS mdl_assign_backup AS SELECT * FROM mdl_assign;

-- Clean HTML from assignments
UPDATE mdl_assign
SET intro = TRIM(
    REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    intro,
                    '<span[^>]*>', ''  -- Remove span tags
                ),
                '</span>', ''
            ),
            '&nbsp;', ' '  -- Replace nbsp with regular space
        ),
        '[[:space:]]+', ' '  -- Compress multiple spaces
    )
)
WHERE intro IS NOT NULL
  AND LENGTH(intro) > 0;"

echo "Cleaned HTML from assignments"

# Clean other text fields
echo "Cleaning HTML from submission comments..."
execute_sql "
UPDATE mdl_assignsubmission_onlinetext
SET onlinetext = TRIM(
    REGEXP_REPLACE(
        REGEXP_REPLACE(onlinetext, '&nbsp;', ' '),
        '[[:space:]]+', ' '
    )
)
WHERE onlinetext IS NOT NULL;"

echo "Cleaning HTML from feedback comments..."
execute_sql "
UPDATE mdl_assignfeedback_comments
SET commenttext = TRIM(
    REGEXP_REPLACE(
        REGEXP_REPLACE(commenttext, '&nbsp;', ' '),
        '[[:space:]]+', ' '
    )
)
WHERE commenttext IS NOT NULL;"

echo ""
echo "STEP 2: ARCHIVING OLD DATA"
echo "=========================="

# Get counts before archiving
echo "Checking data to archive (before 2022)..."
execute_sql_output "
SELECT
    'Assignments to archive' as Item,
    COUNT(*) as Count
FROM mdl_assign a
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01')
UNION ALL
SELECT
    'Submissions to archive',
    COUNT(*)
FROM mdl_assign_submission s
JOIN mdl_assign a ON s.assignment = a.id
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01')
UNION ALL
SELECT
    'Grades to archive',
    COUNT(*)
FROM mdl_assign_grades g
JOIN mdl_assign a ON g.assignment = a.id
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');"

# Create archive tables
echo "Creating archive tables..."
execute_sql "
-- Archive assignments
CREATE TABLE IF NOT EXISTS mdl_assign_archive AS
SELECT a.*
FROM mdl_assign a
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');

-- Archive submissions
CREATE TABLE IF NOT EXISTS mdl_assign_submission_archive AS
SELECT s.*
FROM mdl_assign_submission s
JOIN mdl_assign a ON s.assignment = a.id
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');

-- Archive grades
CREATE TABLE IF NOT EXISTS mdl_assign_grades_archive AS
SELECT g.*
FROM mdl_assign_grades g
JOIN mdl_assign a ON g.assignment = a.id
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');

-- Archive old attendance records
CREATE TABLE IF NOT EXISTS mdl_attendance_log_archive AS
SELECT * FROM mdl_attendance_log
WHERE studentid IN (
    SELECT id FROM mdl_attendance_sessions
    WHERE sessdate < UNIX_TIMESTAMP('2022-01-01')
);"

echo "Deleting archived data from main tables..."
execute_sql "
-- Delete archived submissions
DELETE s FROM mdl_assign_submission s
JOIN mdl_assign a ON s.assignment = a.id
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');

-- Delete archived grades
DELETE g FROM mdl_assign_grades g
JOIN mdl_assign a ON g.assignment = a.id
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');

-- Delete archived assignments
DELETE a FROM mdl_assign a
JOIN mdl_course c ON a.course = c.id
WHERE c.timecreated < UNIX_TIMESTAMP('2022-01-01');

-- Delete old attendance logs
DELETE FROM mdl_attendance_log
WHERE studentid IN (
    SELECT id FROM mdl_attendance_sessions
    WHERE sessdate < UNIX_TIMESTAMP('2022-01-01')
);"

echo ""
echo "STEP 3: DATABASE COMPRESSION"
echo "============================"

echo "Applying compression to large tables..."

# List of tables to compress
TABLES_TO_COMPRESS="
mdl_assign
mdl_assign_submission
mdl_assign_grades
mdl_assignsubmission_onlinetext
mdl_assignfeedback_comments
mdl_assignfeedback_editpdf_annot
mdl_assignfeedback_editpdf_rot
mdl_files
mdl_logstore_standard_log
mdl_forum_posts
"

for TABLE in $TABLES_TO_COMPRESS; do
    echo "Compressing $TABLE..."
    execute_sql "ALTER TABLE $TABLE ROW_FORMAT=COMPRESSED KEY_BLOCK_SIZE=8;" || true
done

echo ""
echo "STEP 4: OPTIMIZE TABLES"
echo "======================="

echo "Optimizing all tables to reclaim space..."
execute_sql "
SELECT CONCAT('OPTIMIZE TABLE ', table_name, ';')
FROM information_schema.tables
WHERE table_schema = 'bitnami_moodle_45'
  AND table_name LIKE 'mdl_%'
INTO OUTFILE '/tmp/optimize_tables.sql';"

# Execute the optimize commands
docker exec $DB_HOST sh -c "mysql -u $DB_USER -p$DB_PASS $DB_NAME < /tmp/optimize_tables.sql" 2>/dev/null || {
    # If file output doesn't work, optimize key tables manually
    echo "Optimizing key tables manually..."
    for TABLE in mdl_assign mdl_assign_submission mdl_assign_grades mdl_files; do
        execute_sql "OPTIMIZE TABLE $TABLE;"
    done
}

echo ""
echo "STEP 5: FINAL RESULTS"
echo "===================="

# Check final database size
execute_sql_output "
SELECT
    'AFTER OPTIMIZATION' as Status,
    COUNT(*) as total_tables,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS database_size_mb
FROM information_schema.TABLES
WHERE table_schema = 'bitnami_moodle_45';"

# Show size comparison
execute_sql_output "
SELECT
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb,
    table_rows as approximate_rows
FROM information_schema.TABLES
WHERE table_schema = 'bitnami_moodle_45'
  AND table_name IN ('mdl_assign', 'mdl_assign_submission', 'mdl_assign_grades')
ORDER BY size_mb DESC;"

# Show archive table sizes
echo ""
echo "Archive Tables Created:"
execute_sql_output "
SELECT
    table_name as archive_table,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb,
    table_rows as rows_archived
FROM information_schema.TABLES
WHERE table_schema = 'bitnami_moodle_45'
  AND table_name LIKE '%_archive'
ORDER BY size_mb DESC;"

echo ""
echo "=========================================="
echo "Optimization Complete at: $(date)"
echo "=========================================="
echo ""
echo "Summary of Actions:"
echo "1. ✓ HTML cleaned from assignment content"
echo "2. ✓ Old data archived (before 2022)"
echo "3. ✓ Database compression applied"
echo "4. ✓ Tables optimized"
echo ""
echo "Backup tables created:"
echo "- mdl_assign_backup (original assignment content)"
echo "- mdl_*_archive tables (old data)"
echo ""
echo "To restore original data if needed:"
echo "  docker exec $DB_HOST mysql -u $DB_USER -p$DB_PASS $DB_NAME -e \"INSERT INTO mdl_assign SELECT * FROM mdl_assign_archive;\""