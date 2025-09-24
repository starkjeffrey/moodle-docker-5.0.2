<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * CLI script to create composite grade structures
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
require_once(__DIR__ . '/../../../config.php');
require_once($CFG->libdir . '/clilib.php');

// Get CLI options
list($options, $unrecognized) = cli_get_params([
    'help' => false,
    'courseid' => null,
    'structure' => 'auto',     // auto, ieap1-ieap6, custom
    'config-file' => null,     // JSON config file
    'list-courses' => false,   // list available courses
    'verbose' => false,
    'dry-run' => false
], [
    'h' => 'help',
    'c' => 'courseid',
    's' => 'structure',
    'f' => 'config-file',
    'l' => 'list-courses',
    'v' => 'verbose',
    'd' => 'dry-run'
]);

if ($options['help']) {
    echo "
Create Composite Grade Structure

Usage:
    php create_composite_structure.php [OPTIONS]

Options:
    -h, --help              Show this help
    -c, --courseid=ID       Course ID to create structure in
    -s, --structure=TYPE    Structure type: auto, ieap1-ieap6, custom (default: auto)
    -f, --config-file=FILE  JSON configuration file for custom structure
    -l, --list-courses      List available courses and exit
    -v, --verbose           Verbose output
    -d, --dry-run           Show what would be created without creating

Structure Types:
    auto    - Auto-detect IEAP level from course name
    ieap1   - IEAP-1 Beginner (Grammar/Vocab 40%, Speaking/Listening 35%, Writing 25%)
    ieap2   - IEAP-2 Elementary (Grammar/Vocab 35%, Speaking/Listening 35%, Writing 30%)
    ieap3   - IEAP-3 Pre-Intermediate (Grammar 30%, Writing 35%, Speaking 20%, Reading/Listening 15%)
    ieap4   - IEAP-4 Intermediate (Grammar 50%, Writing 50%)
    ieap5   - IEAP-5 Upper-Intermediate (Academic Writing 40%, Grammar/Language 25%, Speaking/Presentation 25%, Reading/Critical 10%)
    ieap6   - IEAP-6 Advanced (Academic Writing/Research 45%, Advanced Language 25%, Presentation/Communication 20%, Critical Analysis 10%)
    custom  - Custom structure from JSON file

Custom Structure JSON Format:
{
  \"name\": \"Custom Structure\",
  \"components\": [
    {
      \"name\": \"Component Name\",
      \"weight\": 0.5,
      \"subitems\": [
        {
          \"name\": \"Item Name\",
          \"maxgrade\": 100,
          \"itemtype\": \"manual\"
        }
      ]
    }
  ]
}

Examples:
    # List courses
    php create_composite_structure.php --list-courses

    # Auto-detect IEAP level and create structure
    php create_composite_structure.php --courseid=123 --structure=auto

    # Create specific IEAP level structure
    php create_composite_structure.php --courseid=123 --structure=ieap4

    # Create IEAP-6 (Advanced) structure
    php create_composite_structure.php --courseid=123 --structure=ieap6

    # Create custom structure from file
    php create_composite_structure.php --courseid=123 --structure=custom --config-file=structure.json

    # Dry run to see what would be created
    php create_composite_structure.php --courseid=123 --structure=auto --dry-run --verbose

";
    exit(0);
}

/**
 * List available courses
 */
function list_courses() {
    global $DB;

    $courses = $DB->get_records_sql("
        SELECT c.id, c.shortname, c.fullname, c.category
        FROM {course} c
        WHERE c.id > 1
        ORDER BY c.category, c.shortname
    ");

    if (empty($courses)) {
        mtrace("No courses found.");
        return;
    }

    mtrace("Available Courses:");
    mtrace("ID\tShort Name\tFull Name");
    mtrace(str_repeat("-", 80));

    foreach ($courses as $course) {
        mtrace("{$course->id}\t{$course->shortname}\t{$course->fullname}");
    }
}

/**
 * Auto-detect IEAP level from course information
 */
function detect_ieap_level($courseid) {
    global $DB;

    $course = $DB->get_record('course', ['id' => $courseid], 'shortname, fullname', MUST_EXIST);
    $course_name = $course->shortname . ' ' . $course->fullname;

    return \local_pucsr_api\api\ieap_templates::detect_ieap_level($course_name);
}

/**
 * Get IEAP structure by level
 */
function get_ieap_structure($level) {
    try {
        return \local_pucsr_api\api\ieap_templates::get_template($level);
    } catch (Exception $e) {
        throw new Exception("Invalid IEAP level: {$level}. Valid levels: ieap1, ieap2, ieap3, ieap4, ieap5, ieap6");
    }
}

/**
 * Load custom structure from JSON file
 */
function load_custom_structure($file_path) {
    if (!file_exists($file_path)) {
        throw new Exception("Configuration file not found: {$file_path}");
    }

    $json = file_get_contents($file_path);
    if ($json === false) {
        throw new Exception("Cannot read configuration file: {$file_path}");
    }

    $structure = json_decode($json, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Invalid JSON in configuration file: " . json_last_error_msg());
    }

    // Validate structure
    if (!isset($structure['name']) || !isset($structure['components'])) {
        throw new Exception("Invalid structure format. Must have 'name' and 'components'.");
    }

    $total_weight = 0;
    foreach ($structure['components'] as $component) {
        if (!isset($component['name']) || !isset($component['weight']) || !isset($component['subitems'])) {
            throw new Exception("Invalid component format. Must have 'name', 'weight', and 'subitems'.");
        }
        $total_weight += $component['weight'];
    }

    if (abs($total_weight - 1.0) > 0.001) {
        throw new Exception("Component weights must sum to 1.0 (current sum: {$total_weight})");
    }

    return $structure;
}

/**
 * Display structure preview
 */
function display_structure($structure, $verbose = false) {
    mtrace("Structure: {$structure['name']}");
    mtrace(str_repeat("=", 50));

    foreach ($structure['components'] as $component) {
        $weight_percent = $component['weight'] * 100;
        mtrace("Component: {$component['name']} ({$weight_percent}%)");

        if ($verbose) {
            foreach ($component['subitems'] as $item) {
                mtrace("  - {$item['name']} ({$item['maxgrade']} points, type: {$item['itemtype']})");
            }
        } else {
            mtrace("  Items: " . count($component['subitems']));
        }
        mtrace("");
    }
}

/**
 * Create composite structure
 */
function create_structure($courseid, $structure, $dry_run = false) {
    global $DB;

    // Validate course exists
    $course = $DB->get_record('course', ['id' => $courseid]);
    if (!$course) {
        throw new Exception("Course not found: {$courseid}");
    }

    mtrace("Creating structure for course: {$course->shortname} - {$course->fullname}");

    // Check if structure already exists
    $existing = $DB->get_record('local_pucsr_api_composite_config', [
        'courseid' => $courseid,
        'active' => 1
    ]);

    if ($existing) {
        throw new Exception("Composite structure already exists for this course. Structure: {$existing->structure_name}");
    }

    if ($dry_run) {
        mtrace("[DRY RUN] Would create the following structure:");
        display_structure($structure, true);
        return;
    }

    // Create the structure using the external API
    try {
        $composite_api = new \local_pucsr_api\external\composite_external();
        $result = $composite_api->create_composite_structure($courseid, $structure);

        mtrace("Structure created successfully!");
        mtrace("Main category ID: {$result['main_category_id']}");

        foreach ($result['components'] as $component) {
            mtrace("Component '{$component['name']}' (ID: {$component['category_id']}):");
            foreach ($component['items'] as $item) {
                mtrace("  - {$item['name']} (ID: {$item['id']}, Max: {$item['maxgrade']})");
            }
        }

        return $result;

    } catch (Exception $e) {
        throw new Exception("Failed to create structure: " . $e->getMessage());
    }
}

// Main execution
mtrace("PUCSR Composite Grade Structure Creator");
mtrace("========================================");

try {
    // List courses if requested
    if ($options['list-courses']) {
        list_courses();
        exit(0);
    }

    // Validate required options
    if (!$options['courseid']) {
        throw new Exception("Course ID is required. Use --list-courses to see available courses.");
    }

    if (!is_numeric($options['courseid'])) {
        throw new Exception("Course ID must be numeric.");
    }

    // Get structure configuration
    switch ($options['structure']) {
        case 'auto':
            mtrace("Auto-detecting IEAP level from course information...");
            $detected_level = detect_ieap_level($options['courseid']);
            if ($detected_level) {
                mtrace("Detected IEAP level: {$detected_level}");
                $structure = get_ieap_structure($detected_level);
            } else {
                mtrace("Could not auto-detect IEAP level. Using IEAP-4 as default.");
                $structure = get_ieap_structure('ieap4');
            }
            break;

        case 'ieap1':
        case 'ieap2':
        case 'ieap3':
        case 'ieap4':
        case 'ieap5':
        case 'ieap6':
            $structure = get_ieap_structure($options['structure']);
            break;

        case 'custom':
            if (!$options['config-file']) {
                throw new Exception("Configuration file is required for custom structure.");
            }
            $structure = load_custom_structure($options['config-file']);
            break;

        default:
            throw new Exception("Invalid structure type: {$options['structure']}. Valid types: auto, ieap1-ieap6, custom");
    }

    // Display what will be created
    if ($options['verbose'] || $options['dry-run']) {
        display_structure($structure, $options['verbose']);
        mtrace("");
    }

    // Create the structure
    $result = create_structure($options['courseid'], $structure, $options['dry-run']);

    if (!$options['dry-run']) {
        mtrace("\nNext steps:");
        mtrace("1. Visit the gradebook to verify the structure");
        mtrace("2. Configure any additional grade calculation settings");
        mtrace("3. Start entering grades for students");
        mtrace("\nGradebook URL: {$CFG->wwwroot}/grade/edit/tree/index.php?courseid={$options['courseid']}");
    }

} catch (Exception $e) {
    mtrace("ERROR: " . $e->getMessage());
    exit(1);
}

mtrace("\nOperation completed successfully!");
exit(0);