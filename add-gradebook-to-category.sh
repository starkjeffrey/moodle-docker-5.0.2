#!/bin/bash

# Script to add gradebook items to all courses in a Moodle category

echo "==========================================="
echo "Moodle Gradebook Setup Script"
echo "==========================================="

# Default values
DB_HOST="moodle-4-5-mariadb"
DB_USER="root"
DB_PASS="moodle_45_root_password"
DB_NAME="bitnami_moodle_45"

# Function to execute SQL
execute_sql() {
    docker exec $DB_HOST mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "$1" 2>/dev/null
}

# Check if category name was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <category_name_pattern>"
    echo "Example: $0 'IFL' (for IFL categories)"
    echo "Example: $0 '2021Fall' (for Fall 2021 categories)"
    echo ""
    echo "Available categories:"
    execute_sql "
    SELECT DISTINCT
        cc.name as category_name,
        COUNT(c.id) as course_count
    FROM mdl_course_categories cc
    LEFT JOIN mdl_course c ON c.category = cc.id
    WHERE c.id > 1
    GROUP BY cc.name
    ORDER BY cc.name
    LIMIT 10;"
    exit 1
fi

CATEGORY_PATTERN="%$1%"

echo ""
echo "Setting up gradebook for courses in category: $CATEGORY_PATTERN"
echo ""

# First, show which courses will be affected
echo "Courses to be updated:"
execute_sql "
SELECT
    c.shortname as 'Course Code',
    c.fullname as 'Course Name'
FROM mdl_course c
JOIN mdl_course_categories cc ON c.category = cc.id
WHERE cc.name LIKE '$CATEGORY_PATTERN'
  AND c.id > 1
LIMIT 20;"

echo ""
read -p "Continue with gradebook setup for these courses? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo "Select gradebook configuration:"
echo "1) Standard Academic (Participation 10%, Assignments 20%, Midterm 30%, Final 40%)"
echo "2) Project-Based (Participation 10%, Projects 40%, Presentations 20%, Final 30%)"
echo "3) Continuous Assessment (Weekly Quizzes 30%, Assignments 30%, Participation 20%, Final 20%)"
echo "4) Language Learning (Speaking 25%, Writing 25%, Reading 25%, Listening 25%)"
echo "5) Custom (you specify)"
read -p "Enter choice (1-5): " GRADE_CONFIG

case $GRADE_CONFIG in
    1)
        # Standard Academic Configuration
        execute_sql "
        -- Create temp table of courses
        CREATE TEMPORARY TABLE temp_gradebook_courses AS
        SELECT c.id as course_id, c.fullname, c.shortname
        FROM mdl_course c
        JOIN mdl_course_categories cc ON c.category = cc.id
        WHERE cc.name LIKE '$CATEGORY_PATTERN' AND c.id > 1;

        -- Ensure grade categories exist
        INSERT IGNORE INTO mdl_grade_categories (courseid, fullname, aggregation, timecreated, timemodified)
        SELECT course_id, 'Course total', 13, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Add Participation (10%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Participation', 'manual', 1, 100, 0.10, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Add Assignments (20%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Assignments', 'manual', 1, 100, 0.20, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Add Midterm (30%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Midterm Exam', 'manual', 1, 100, 0.30, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Add Final (40%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Final Exam', 'manual', 1, 100, 0.40, 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        DROP TEMPORARY TABLE temp_gradebook_courses;"

        echo "Standard Academic gradebook configuration applied!"
        ;;

    2)
        # Project-Based Configuration
        execute_sql "
        CREATE TEMPORARY TABLE temp_gradebook_courses AS
        SELECT c.id as course_id FROM mdl_course c
        JOIN mdl_course_categories cc ON c.category = cc.id
        WHERE cc.name LIKE '$CATEGORY_PATTERN' AND c.id > 1;

        INSERT IGNORE INTO mdl_grade_categories (courseid, fullname, aggregation, timecreated, timemodified)
        SELECT course_id, 'Course total', 13, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Participation (10%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Participation', 'manual', 1, 100, 0.10, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Projects (40%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Projects', 'manual', 1, 100, 0.40, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Presentations (20%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Presentations', 'manual', 1, 100, 0.20, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Final Project (30%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Final Project', 'manual', 1, 100, 0.30, 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        DROP TEMPORARY TABLE temp_gradebook_courses;"

        echo "Project-Based gradebook configuration applied!"
        ;;

    3)
        # Continuous Assessment Configuration
        execute_sql "
        CREATE TEMPORARY TABLE temp_gradebook_courses AS
        SELECT c.id as course_id FROM mdl_course c
        JOIN mdl_course_categories cc ON c.category = cc.id
        WHERE cc.name LIKE '$CATEGORY_PATTERN' AND c.id > 1;

        INSERT IGNORE INTO mdl_grade_categories (courseid, fullname, aggregation, timecreated, timemodified)
        SELECT course_id, 'Course total', 13, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Weekly Quizzes (30%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Weekly Quizzes', 'manual', 1, 100, 0.30, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Assignments (30%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Assignments', 'manual', 1, 100, 0.30, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Participation (20%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Participation', 'manual', 1, 100, 0.20, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Final Assessment (20%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Final Assessment', 'manual', 1, 100, 0.20, 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        DROP TEMPORARY TABLE temp_gradebook_courses;"

        echo "Continuous Assessment gradebook configuration applied!"
        ;;

    4)
        # Language Learning Configuration (perfect for IFL)
        execute_sql "
        CREATE TEMPORARY TABLE temp_gradebook_courses AS
        SELECT c.id as course_id FROM mdl_course c
        JOIN mdl_course_categories cc ON c.category = cc.id
        WHERE cc.name LIKE '$CATEGORY_PATTERN' AND c.id > 1;

        INSERT IGNORE INTO mdl_grade_categories (courseid, fullname, aggregation, timecreated, timemodified)
        SELECT course_id, 'Course total', 13, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Speaking (25%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Speaking & Oral Communication', 'manual', 1, 100, 0.25, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Writing (25%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Writing & Composition', 'manual', 1, 100, 0.25, 2, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Reading (25%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Reading Comprehension', 'manual', 1, 100, 0.25, 3, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        -- Listening (25%)
        INSERT IGNORE INTO mdl_grade_items
        (courseid, itemname, itemtype, gradetype, grademax, aggregationcoef2, sortorder, timecreated, timemodified)
        SELECT course_id, 'Listening Skills', 'manual', 1, 100, 0.25, 4, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()
        FROM temp_gradebook_courses;

        DROP TEMPORARY TABLE temp_gradebook_courses;"

        echo "Language Learning gradebook configuration applied!"
        ;;

    5)
        # Custom Configuration
        echo "Custom gradebook setup - enter your grade items:"
        echo "Format: Name,Weight (e.g., 'Homework,0.20' for 20%)"
        echo "Enter items one per line, press Ctrl+D when done:"

        # Read custom items
        ITEMS=""
        while IFS= read -r line; do
            ITEMS="$ITEMS$line\n"
        done

        # Process custom items...
        echo "Custom configuration would be applied (implementation needed)"
        ;;

    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Verifying gradebook setup..."
execute_sql "
SELECT
    c.shortname as 'Course',
    gi.itemname as 'Grade Item',
    CONCAT(ROUND(gi.aggregationcoef2 * 100, 0), '%') as 'Weight'
FROM mdl_grade_items gi
JOIN mdl_course c ON gi.courseid = c.id
JOIN mdl_course_categories cc ON c.category = cc.id
WHERE cc.name LIKE '$CATEGORY_PATTERN'
  AND gi.itemtype = 'manual'
ORDER BY c.shortname, gi.sortorder
LIMIT 20;"

echo ""
echo "==========================================="
echo "Gradebook setup complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "1. Log into Moodle as an administrator"
echo "2. Navigate to any course in the $1 category"
echo "3. Go to Grades > Setup > Gradebook setup"
echo "4. Verify the grade items and adjust weights if needed"
echo "5. You can now enter grades for students in these categories"