#!/bin/bash

# Backup MODEL courses with their gradebook structure for migration

echo "==========================================="
echo "Backing up MODEL Courses with Gradebooks"
echo "==========================================="

DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

echo "Creating backup of MODEL courses gradebook structure..."

# Method 1: SQL backup of gradebook structure only
docker exec $DB_HOST mariadb-dump \
    -u $DB_USER \
    -p$DB_PASS \
    $DB_NAME \
    --single-transaction \
    --no-create-info \
    --where="courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%')" \
    mdl_grade_items \
    mdl_grade_categories > $BACKUP_DIR/model_gradebooks_${TIMESTAMP}.sql 2>/dev/null

# Add course mapping for reference
docker exec $DB_HOST mariadb -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT
    c.id as course_id,
    c.shortname,
    c.fullname
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
ORDER BY c.shortname;" 2>/dev/null > $BACKUP_DIR/model_course_mapping_${TIMESTAMP}.txt

# Method 2: Create a migration script that can be run on production
cat > $BACKUP_DIR/migrate_model_gradebooks_${TIMESTAMP}.sql << 'EOF'
-- Migration script for MODEL course gradebooks
-- Run this on your production Moodle database

-- Step 1: Create grade categories for MODEL courses if they don't exist
INSERT IGNORE INTO mdl_grade_categories
(courseid, fullname, aggregation, timecreated, timemodified)
SELECT
    c.id,
    'Course total',
    13,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%';

-- Step 2: Add Exam I Total and Attendance
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Exam I Total', 'manual', 'First examination period',
    CONCAT('EXAM1_', c.id), 1, 100.00, 0.00, 60.00, 0.30, 10, NULL,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (SELECT 1 FROM mdl_grade_items gi WHERE gi.courseid = c.id AND gi.itemname = 'Exam I Total');

INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Days Absent - Exam I Period', 'manual', 'Attendance up to Exam I (not graded)',
    CONCAT('ABSENT_EXAM1_', c.id), 1, 30.00, 0.00, 0.00, 11, 2,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (SELECT 1 FROM mdl_grade_items gi WHERE gi.courseid = c.id AND gi.itemname = 'Days Absent - Exam I Period');

-- Step 3: Add Exam II Total and Attendance
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Exam II Total', 'manual', 'Second examination period',
    CONCAT('EXAM2_', c.id), 1, 100.00, 0.00, 60.00, 0.35, 20, NULL,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (SELECT 1 FROM mdl_grade_items gi WHERE gi.courseid = c.id AND gi.itemname = 'Exam II Total');

INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Days Absent - Exam II Period', 'manual', 'Attendance from Exam I to Exam II (not graded)',
    CONCAT('ABSENT_EXAM2_', c.id), 1, 30.00, 0.00, 0.00, 21, 2,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (SELECT 1 FROM mdl_grade_items gi WHERE gi.courseid = c.id AND gi.itemname = 'Days Absent - Exam II Period');

-- Step 4: Add Exam III Total and Attendance (for select courses)
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Exam III Total', 'manual', 'Final examination period',
    CONCAT('EXAM3_', c.id), 1, 100.00, 0.00, 60.00, 0.35, 30, NULL,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND (c.shortname LIKE '%FINAL%' OR c.shortname LIKE '%-12-%' OR c.shortname LIKE '%ADV%')
  AND NOT EXISTS (SELECT 1 FROM mdl_grade_items gi WHERE gi.courseid = c.id AND gi.itemname = 'Exam III Total');

INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Days Absent - Exam III Period', 'manual', 'Attendance from Exam II to Exam III (not graded)',
    CONCAT('ABSENT_EXAM3_', c.id), 1, 30.00, 0.00, 0.00, 31, 2,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
JOIN mdl_grade_items gi ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%'
  AND gi.itemname = 'Exam III Total'
  AND NOT EXISTS (SELECT 1 FROM mdl_grade_items gi2 WHERE gi2.courseid = c.id AND gi2.itemname = 'Days Absent - Exam III Period');

-- Verification
SELECT
    'Migration Complete' as Status,
    COUNT(DISTINCT c.id) as MODEL_Courses,
    SUM(CASE WHEN gi.itemname LIKE 'Exam%Total' THEN 1 ELSE 0 END) as Exam_Items,
    SUM(CASE WHEN gi.itemname LIKE 'Days Absent%' THEN 1 ELSE 0 END) as Attendance_Items
FROM mdl_course c
LEFT JOIN mdl_grade_items gi ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%';
EOF

# Method 3: Export specific gradebook data for verification
docker exec $DB_HOST mariadb -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT
    c.shortname as course,
    gi.itemname,
    gi.itemtype,
    gi.idnumber,
    gi.gradetype,
    gi.grademax,
    gi.grademin,
    gi.gradepass,
    gi.aggregationcoef2,
    gi.sortorder,
    gi.decimals
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%'
  AND gi.itemtype = 'manual'
ORDER BY c.shortname, gi.sortorder;" 2>/dev/null > $BACKUP_DIR/model_gradebook_export_${TIMESTAMP}.csv

echo ""
echo "Backup files created:"
echo "1. $BACKUP_DIR/model_gradebooks_${TIMESTAMP}.sql"
echo "   - Raw SQL backup of grade items and categories"
echo ""
echo "2. $BACKUP_DIR/migrate_model_gradebooks_${TIMESTAMP}.sql"
echo "   - Migration script to run on production Moodle"
echo ""
echo "3. $BACKUP_DIR/model_course_mapping_${TIMESTAMP}.txt"
echo "   - Course ID mapping for reference"
echo ""
echo "4. $BACKUP_DIR/model_gradebook_export_${TIMESTAMP}.csv"
echo "   - CSV export of gradebook structure"
echo ""
echo "==========================================="
echo "To apply to production Moodle:"
echo "==========================================="
echo ""
echo "Option 1: Run migration script"
echo "   mysql -u moodle_user -p production_database < migrate_model_gradebooks_${TIMESTAMP}.sql"
echo ""
echo "Option 2: Use Moodle backup/restore"
echo "   1. Log into this test Moodle as admin"
echo "   2. Go to each MODEL course"
echo "   3. Settings > Backup (include grade history and configuration)"
echo "   4. Download .mbz file"
echo "   5. Restore to production Moodle"
echo ""
echo "Option 3: Use Moodle Web Services API"
echo "   - Use the CSV export as reference"
echo "   - Create grade items via API calls"
echo ""
echo "IMPORTANT: Always backup production database before applying changes!"