#!/bin/bash

# Clean up duplicate grade items in MODEL courses

echo "==========================================="
echo "Cleaning MODEL Course Gradebooks"
echo "==========================================="

DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"

# Function to execute SQL
execute_sql() {
    docker exec $DB_HOST mariadb -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

echo "Checking for duplicates..."

execute_sql "
SELECT
    c.shortname as Course,
    gi.itemname as Item,
    COUNT(*) as Duplicates
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%'
  AND gi.itemtype = 'manual'
GROUP BY c.id, gi.itemname
HAVING COUNT(*) > 1
LIMIT 10;"

echo ""
echo "Removing duplicate grade items..."

execute_sql "
-- Remove duplicates, keeping only the one with the lowest ID
DELETE gi1 FROM mdl_grade_items gi1
INNER JOIN mdl_grade_items gi2
WHERE gi1.courseid = gi2.courseid
  AND gi1.itemname = gi2.itemname
  AND gi1.itemtype = 'manual'
  AND gi1.id > gi2.id
  AND gi1.courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%');

SELECT ROW_COUNT() as 'Duplicate Items Removed';"

echo ""
echo "Removing duplicate categories..."

execute_sql "
DELETE gc1 FROM mdl_grade_categories gc1
INNER JOIN mdl_grade_categories gc2
WHERE gc1.courseid = gc2.courseid
  AND gc1.fullname = gc2.fullname
  AND gc1.id > gc2.id
  AND gc1.courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%');

SELECT ROW_COUNT() as 'Duplicate Categories Removed';"

echo ""
echo "Verifying cleanup..."

execute_sql "
SELECT
    'Cleanup Complete' as Status,
    COUNT(DISTINCT c.id) as 'MODEL Courses',
    COUNT(DISTINCT gi.id) as 'Total Grade Items',
    SUM(CASE WHEN gi.itemname LIKE 'Exam%Total' THEN 1 ELSE 0 END) as 'Exam Items',
    SUM(CASE WHEN gi.itemname LIKE 'Days Absent%' THEN 1 ELSE 0 END) as 'Attendance Items'
FROM mdl_course c
LEFT JOIN mdl_grade_items gi ON gi.courseid = c.id AND gi.itemtype = 'manual'
WHERE c.shortname LIKE 'MODEL-%';"

echo ""
echo "==========================================="
echo "Creating cleaned migration script..."
echo "==========================================="

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

cat > ./backups/migrate_model_gradebooks_clean_${TIMESTAMP}.sql << 'EOF'
-- Clean Migration Script for MODEL Course Gradebooks
-- This version prevents duplicates

-- Step 0: Clean any existing duplicates
DELETE gi1 FROM mdl_grade_items gi1
INNER JOIN mdl_grade_items gi2
WHERE gi1.courseid = gi2.courseid
  AND gi1.itemname = gi2.itemname
  AND gi1.itemtype = 'manual'
  AND gi1.id > gi2.id
  AND gi1.courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%');

-- Step 1: Create grade categories (only if not exists)
INSERT INTO mdl_grade_categories
(courseid, fullname, aggregation, timecreated, timemodified)
SELECT
    c.id,
    'Course total',
    13,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_categories gc
    WHERE gc.courseid = c.id AND gc.fullname = 'Course total'
  );

-- Step 2: Add Exam I Total (checking for duplicates)
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, timecreated, timemodified)
SELECT
    c.id, 'Exam I Total', 'manual', 'First examination period',
    CONCAT('EXAM1_', c.id), 1, 100.00, 0.00, 60.00, 0.30, 10,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Exam I Total'
  );

-- Step 3: Add Days Absent - Exam I (not graded)
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Days Absent - Exam I Period', 'manual',
    'Attendance up to Exam I (not graded)',
    CONCAT('ABSENT_EXAM1_', c.id), 1, 30.00, 0.00, 0.00, 11, 2,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Days Absent - Exam I Period'
  );

-- Step 4: Add Exam II Total
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, timecreated, timemodified)
SELECT
    c.id, 'Exam II Total', 'manual', 'Second examination period',
    CONCAT('EXAM2_', c.id), 1, 100.00, 0.00, 60.00, 0.35, 20,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Exam II Total'
  );

-- Step 5: Add Days Absent - Exam II
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id, 'Days Absent - Exam II Period', 'manual',
    'Attendance from Exam I to Exam II (not graded)',
    CONCAT('ABSENT_EXAM2_', c.id), 1, 30.00, 0.00, 0.00, 21, 2,
    UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Days Absent - Exam II Period'
  );

-- Verification
SELECT
    'Migration Complete' as Status,
    COUNT(DISTINCT c.id) as MODEL_Courses,
    SUM(CASE WHEN gi.itemname LIKE 'Exam%Total' THEN 1 ELSE 0 END) as Exam_Items,
    SUM(CASE WHEN gi.itemname LIKE 'Days Absent%' THEN 1 ELSE 0 END) as Attendance_Items
FROM mdl_course c
LEFT JOIN mdl_grade_items gi ON gi.courseid = c.id AND gi.itemtype = 'manual'
WHERE c.shortname LIKE 'MODEL-%';
EOF

echo ""
echo "Clean migration script created:"
echo "./backups/migrate_model_gradebooks_clean_${TIMESTAMP}.sql"
echo ""
echo "This script:"
echo "• Removes any existing duplicates"
echo "• Uses NOT EXISTS checks to prevent creating duplicates"
echo "• Safe to run multiple times"
echo ""
echo "To apply to production:"
echo "mysql -u moodle_user -p production_db < ./backups/migrate_model_gradebooks_clean_${TIMESTAMP}.sql"