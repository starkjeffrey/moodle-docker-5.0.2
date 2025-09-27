#!/bin/bash

# Position attendance items right after each Exam Total

echo "==========================================="
echo "Positioning Attendance After Exam Totals"
echo "==========================================="

DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"

# Function to execute SQL
execute_sql() {
    docker exec $DB_HOST mariadb -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

echo "Finding Exam Total items in MODEL courses..."

# First check what exam items exist
execute_sql "
SELECT
    COUNT(DISTINCT gi.itemname) as 'Unique Exam Items',
    GROUP_CONCAT(DISTINCT gi.itemname ORDER BY gi.itemname SEPARATOR ', ') as 'Exam Item Names'
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%'
  AND gi.itemname LIKE '%Exam%Total%';"

echo ""
echo "Removing old attendance items if they exist..."

execute_sql "
DELETE FROM mdl_grade_items
WHERE itemname LIKE 'Days Absent%'
  AND courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%');
SELECT ROW_COUNT() as 'Old Items Removed';"

echo ""
echo "Adding attendance tracking after each Exam Total..."

# Add attendance items with proper positioning
execute_sql "
-- Create temporary table with exam positions
CREATE TEMPORARY TABLE exam_positions AS
SELECT
    gi.courseid,
    gi.itemname as exam_name,
    gi.sortorder as exam_sortorder,
    CASE
        WHEN gi.itemname LIKE '%I Total%' OR gi.itemname LIKE '%1 Total%' THEN 1
        WHEN gi.itemname LIKE '%II Total%' OR gi.itemname LIKE '%2 Total%' THEN 2
        WHEN gi.itemname LIKE '%III Total%' OR gi.itemname LIKE '%3 Total%' THEN 3
        ELSE 0
    END as exam_number
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%'
  AND gi.itemname LIKE '%Exam%Total%';

-- Add Days Absent after Exam I Total
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef, aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    ep.courseid,
    'Days Absent - Exam I Period',
    'manual',
    'Attendance up to Exam I (not graded)',
    CONCAT('ABSENT_EXAM1_', ep.courseid),
    1,
    30.00,
    0.00,
    0.00,
    0.00,
    ep.exam_sortorder + 0.5,  -- Position right after exam
    2,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM exam_positions ep
WHERE ep.exam_number = 1;

SELECT ROW_COUNT() as 'Exam I Attendance Items Added';

-- Add Days Absent after Exam II Total
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef, aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    ep.courseid,
    'Days Absent - Exam II Period',
    'manual',
    'Attendance from Exam I to Exam II (not graded)',
    CONCAT('ABSENT_EXAM2_', ep.courseid),
    1,
    30.00,
    0.00,
    0.00,
    0.00,
    ep.exam_sortorder + 0.5,
    2,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM exam_positions ep
WHERE ep.exam_number = 2;

SELECT ROW_COUNT() as 'Exam II Attendance Items Added';

-- Add Days Absent after Exam III Total (where it exists)
INSERT INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef, aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    ep.courseid,
    'Days Absent - Exam III Period',
    'manual',
    'Attendance from Exam II to Exam III (not graded)',
    CONCAT('ABSENT_EXAM3_', ep.courseid),
    1,
    30.00,
    0.00,
    0.00,
    0.00,
    ep.exam_sortorder + 0.5,
    2,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM exam_positions ep
WHERE ep.exam_number = 3;

SELECT ROW_COUNT() as 'Exam III Attendance Items Added';

DROP TEMPORARY TABLE exam_positions;"

echo ""
echo "Verifying positioning..."

execute_sql "
-- Show sample course with exam and attendance items
SELECT
    gi.itemname as 'Grade Item',
    gi.sortorder as 'Sort Position',
    CASE
        WHEN gi.aggregationcoef2 = 0 THEN 'Not counted in grade'
        WHEN gi.aggregationcoef2 IS NULL THEN 'Category'
        ELSE CONCAT(ROUND(gi.aggregationcoef2 * 100), '%')
    END as 'Weight'
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE c.shortname = 'MODEL-GESL-08-COMM'
  AND (gi.itemname LIKE '%Exam%' OR gi.itemname LIKE 'Days Absent%')
ORDER BY gi.sortorder
LIMIT 15;"

echo ""
echo "Summary:"
execute_sql "
SELECT
    COUNT(DISTINCT courseid) as 'Courses with Attendance',
    COUNT(*) as 'Total Attendance Items',
    GROUP_CONCAT(DISTINCT itemname ORDER BY itemname SEPARATOR ' | ') as 'Attendance Types'
FROM mdl_grade_items
WHERE itemname LIKE 'Days Absent - Exam%'
  AND courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%');"

echo ""
echo "==========================================="
echo "Attendance Positioning Complete!"
echo "==========================================="
echo ""
echo "Attendance items now appear:"
echo "• Right after 'Exam I Total' → 'Days Absent - Exam I Period'"
echo "• Right after 'Exam II Total' → 'Days Absent - Exam II Period'"
echo "• Right after 'Exam III Total' → 'Days Absent - Exam III Period' (where applicable)"
echo ""
echo "All attendance items:"
echo "• Accept floating point values (e.g., 5.75 days)"
echo "• Show 2 decimal places"
echo "• Weight = 0% (not counted in grades)"
echo "• Visible to students as reference"