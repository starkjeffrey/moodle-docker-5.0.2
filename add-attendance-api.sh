#!/bin/bash

# Add attendance tracking items to MODEL courses for API integration
# These items accept floating point numbers and DO NOT count in grades

echo "==========================================="
echo "Adding Attendance Tracking to MODEL Courses"
echo "==========================================="

DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"

# Function to execute SQL
execute_sql() {
    docker exec $DB_HOST mariadb -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

echo "Finding MODEL courses..."
execute_sql "SELECT COUNT(*) as 'MODEL Courses Found' FROM mdl_course WHERE shortname LIKE 'MODEL-%';"

echo ""
echo "Adding attendance tracking items..."

# Add both attendance items in one go
execute_sql "
-- Add attendance tracking for Midterm Period
INSERT INTO mdl_grade_items
(
    courseid,
    categoryid,
    itemname,
    itemtype,
    iteminfo,
    idnumber,
    gradetype,
    grademax,
    grademin,
    gradepass,
    multfactor,
    plusfactor,
    aggregationcoef,
    aggregationcoef2,
    sortorder,
    display,
    decimals,
    hidden,
    locked,
    timecreated,
    timemodified
)
SELECT
    c.id as courseid,
    NULL as categoryid,
    'Days Absent - Midterm Period' as itemname,
    'manual' as itemtype,
    'Number of days absent up to midterm (API updated, not graded)' as iteminfo,
    CONCAT('ABSENT_MID_', c.id) as idnumber,
    1 as gradetype,           -- Value type (accepts decimals)
    30.00 as grademax,        -- Max 30 days
    0.00 as grademin,         -- Min 0 days
    0.00 as gradepass,        -- No pass threshold
    1.00 as multfactor,
    0.00 as plusfactor,
    0.00 as aggregationcoef,  -- Not aggregated
    0.00 as aggregationcoef2, -- Weight = 0% (not counted in grade)
    50 as sortorder,          -- After midterm items
    0 as display,             -- Default display
    2 as decimals,            -- Show 2 decimal places (e.g., 5.75 days)
    0 as hidden,              -- Visible to students
    0 as locked,              -- Not locked
    UNIX_TIMESTAMP() as timecreated,
    UNIX_TIMESTAMP() as timemodified
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id
    AND gi.itemname = 'Days Absent - Midterm Period'
  );

SELECT ROW_COUNT() as 'Midterm Attendance Items Added';

-- Add attendance tracking for Final Period
INSERT INTO mdl_grade_items
(
    courseid,
    categoryid,
    itemname,
    itemtype,
    iteminfo,
    idnumber,
    gradetype,
    grademax,
    grademin,
    gradepass,
    multfactor,
    plusfactor,
    aggregationcoef,
    aggregationcoef2,
    sortorder,
    display,
    decimals,
    hidden,
    locked,
    timecreated,
    timemodified
)
SELECT
    c.id as courseid,
    NULL as categoryid,
    'Days Absent - Final Period' as itemname,
    'manual' as itemtype,
    'Number of days absent from midterm to final (API updated, not graded)' as iteminfo,
    CONCAT('ABSENT_FINAL_', c.id) as idnumber,
    1 as gradetype,
    30.00 as grademax,
    0.00 as grademin,
    0.00 as gradepass,
    1.00 as multfactor,
    0.00 as plusfactor,
    0.00 as aggregationcoef,
    0.00 as aggregationcoef2,  -- Weight = 0% (not counted)
    100 as sortorder,           -- After final items
    0 as display,
    2 as decimals,              -- 2 decimal places
    0 as hidden,
    0 as locked,
    UNIX_TIMESTAMP() as timecreated,
    UNIX_TIMESTAMP() as timemodified
FROM mdl_course c
WHERE c.shortname LIKE 'MODEL-%'
  AND NOT EXISTS (
    SELECT 1 FROM mdl_grade_items gi
    WHERE gi.courseid = c.id
    AND gi.itemname = 'Days Absent - Final Period'
  );"

echo ""
echo "Verifying attendance tracking setup..."
execute_sql "
SELECT
    c.shortname as 'Sample Course',
    gi.itemname as 'Attendance Item',
    gi.idnumber as 'API ID',
    gi.grademax as 'Max Days',
    gi.decimals as 'Decimals',
    CASE
        WHEN gi.aggregationcoef2 = 0 THEN 'Not counted in grade'
        ELSE CONCAT(ROUND(gi.aggregationcoef2 * 100), '%')
    END as 'Weight'
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
WHERE gi.itemname LIKE 'Days Absent%'
  AND c.shortname IN ('MODEL-GESL-08-COMM', 'MODEL-GESL-08-FOUR', 'MODEL-EHSS-01-VEN')
ORDER BY c.shortname, gi.sortorder;"

echo ""
echo "Summary:"
execute_sql "
SELECT
    COUNT(DISTINCT courseid) as 'MODEL Courses with Attendance',
    COUNT(*) as 'Total Attendance Items',
    GROUP_CONCAT(DISTINCT itemname SEPARATOR ', ') as 'Item Types'
FROM mdl_grade_items
WHERE itemname LIKE 'Days Absent%'
  AND courseid IN (SELECT id FROM mdl_course WHERE shortname LIKE 'MODEL-%');"

echo ""
echo "==========================================="
echo "Attendance Tracking Setup Complete!"
echo "==========================================="
echo ""
echo "What was configured:"
echo "• Days Absent - Midterm Period (0-30 days, 2 decimal places)"
echo "• Days Absent - Final Period (0-30 days, 2 decimal places)"
echo "• Weight: 0% (not counted in final grade)"
echo "• Visibility: Shown to students as reference"
echo ""
echo "API Integration:"
echo "• Use idnumber field for API updates:"
echo "  - ABSENT_MID_{course_id} for midterm attendance"
echo "  - ABSENT_FINAL_{course_id} for final attendance"
echo "• Accepts floating point values (e.g., 5.75 days)"
echo ""
echo "Example API call to update attendance:"
echo "POST /webservice/rest/server.php"
echo "  function=core_grades_update_grades"
echo "  grades[0][itemid]={grade_item_id}"
echo "  grades[0][userid]={student_id}"
echo "  grades[0][rawgrade]=5.75"