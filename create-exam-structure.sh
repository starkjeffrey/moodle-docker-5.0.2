#!/bin/bash

# Create Exam Total structure and attendance tracking for MODEL courses

echo "==========================================="
echo "Creating Exam Structure for MODEL Courses"
echo "==========================================="

DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"

# Function to execute SQL
execute_sql() {
    docker exec $DB_HOST mariadb -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

echo "Setting up exam structure for MODEL courses..."

execute_sql "
-- First ensure grade categories exist for MODEL courses
INSERT IGNORE INTO mdl_grade_categories
(courseid, fullname, aggregation, timecreated, timemodified)
SELECT
    c.id,
    'Course total',
    13,  -- Weighted mean
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%';

-- Add Exam I Total (30% weight)
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, timecreated, timemodified)
SELECT
    c.id,
    'Exam I Total',
    'manual',
    'First examination period',
    CONCAT('EXAM1_', c.id),
    1,
    100.00,
    0.00,
    60.00,
    0.30,  -- 30% weight
    10,    -- Sort order
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Exam I Total'
  );

SELECT ROW_COUNT() as 'Exam I Total items created';

-- Add Days Absent after Exam I (not graded)
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id,
    'Days Absent - Exam I Period',
    'manual',
    'Attendance up to Exam I (not graded)',
    CONCAT('ABSENT_EXAM1_', c.id),
    1,
    30.00,
    0.00,
    0.00,  -- Weight 0% (not counted)
    11,    -- Right after Exam I
    2,     -- 2 decimal places
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Days Absent - Exam I Period'
  );

-- Add Exam II Total (35% weight)
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, timecreated, timemodified)
SELECT
    c.id,
    'Exam II Total',
    'manual',
    'Second examination period',
    CONCAT('EXAM2_', c.id),
    1,
    100.00,
    0.00,
    60.00,
    0.35,  -- 35% weight
    20,    -- Sort order
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Exam II Total'
  );

SELECT ROW_COUNT() as 'Exam II Total items created';

-- Add Days Absent after Exam II (not graded)
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id,
    'Days Absent - Exam II Period',
    'manual',
    'Attendance from Exam I to Exam II (not graded)',
    CONCAT('ABSENT_EXAM2_', c.id),
    1,
    30.00,
    0.00,
    0.00,  -- Weight 0% (not counted)
    21,    -- Right after Exam II
    2,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Days Absent - Exam II Period'
  );

-- Add Exam III Total for specific courses (35% weight)
-- Only add for courses that would typically have 3 exams
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 gradepass, aggregationcoef2, sortorder, timecreated, timemodified)
SELECT
    c.id,
    'Exam III Total',
    'manual',
    'Final examination period',
    CONCAT('EXAM3_', c.id),
    1,
    100.00,
    0.00,
    60.00,
    0.35,  -- 35% weight
    30,    -- Sort order
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND (c.shortname LIKE '%FINAL%' OR c.shortname LIKE '%-12-%' OR c.shortname LIKE '%ADV%')
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id AND gi.itemname = 'Exam III Total'
  );

SELECT ROW_COUNT() as 'Exam III Total items created (select courses)';

-- Add Days Absent after Exam III (where Exam III exists)
INSERT IGNORE INTO mdl_grade_items
(courseid, itemname, itemtype, iteminfo, idnumber, gradetype, grademax, grademin,
 aggregationcoef2, sortorder, decimals, timecreated, timemodified)
SELECT
    c.id,
    'Days Absent - Exam III Period',
    'manual',
    'Attendance from Exam II to Exam III (not graded)',
    CONCAT('ABSENT_EXAM3_', c.id),
    1,
    30.00,
    0.00,
    0.00,  -- Weight 0% (not counted)
    31,    -- Right after Exam III
    2,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM mdl_course c
JOIN mdl_grade_items gi ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%'
  AND gi.itemname = 'Exam III Total'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi2
    WHERE gi2.courseid = c.id AND gi2.itemname = 'Days Absent - Exam III Period'
  );

SELECT ROW_COUNT() as 'Days Absent - Exam III items created';"

echo ""
echo "Verifying exam structure..."

execute_sql "
-- Show sample course structure
SELECT
    gi.itemname as 'Grade Item',
    gi.sortorder as 'Position',
    CASE
        WHEN gi.itemtype = 'course' THEN 'Course Total'
        WHEN gi.aggregationcoef2 = 0 THEN 'Not counted'
        WHEN gi.aggregationcoef2 IS NULL THEN 'Category'
        ELSE CONCAT(ROUND(gi.aggregationcoef2 * 100), '%')
    END as 'Weight',
    gi.grademax as 'Max Points',
    gi.decimals as 'Decimals'
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE c.shortname = 'MODEL-GESL-08-COMM'
ORDER BY gi.sortorder
LIMIT 15;"

echo ""
echo "Summary:"
execute_sql "
SELECT
    COUNT(DISTINCT c.id) as 'MODEL Courses',
    SUM(CASE WHEN gi.itemname = 'Exam I Total' THEN 1 ELSE 0 END) as 'Exam I Items',
    SUM(CASE WHEN gi.itemname = 'Exam II Total' THEN 1 ELSE 0 END) as 'Exam II Items',
    SUM(CASE WHEN gi.itemname = 'Exam III Total' THEN 1 ELSE 0 END) as 'Exam III Items',
    SUM(CASE WHEN gi.itemname LIKE 'Days Absent%' THEN 1 ELSE 0 END) as 'Attendance Items'
FROM mdl_course c
LEFT JOIN mdl_grade_items gi ON gi.courseid = c.id
WHERE c.shortname LIKE 'MODEL-%';"

echo ""
echo "==========================================="
echo "Exam Structure Setup Complete!"
echo "==========================================="
echo ""
echo "Created for all MODEL courses:"
echo "• Exam I Total (30% weight)"
echo "• Days Absent - Exam I Period (0% weight, reference only)"
echo "• Exam II Total (35% weight)"
echo "• Days Absent - Exam II Period (0% weight, reference only)"
echo ""
echo "For select advanced courses:"
echo "• Exam III Total (35% weight)"
echo "• Days Absent - Exam III Period (0% weight, reference only)"
echo ""
echo "Attendance tracking features:"
echo "• Accepts floating point values (e.g., 5.75 days)"
echo "• Shows 2 decimal places"
echo "• Does NOT count toward final grade"
echo "• Ready for API integration with SIS"