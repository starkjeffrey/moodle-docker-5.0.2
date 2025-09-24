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
 * SIS Synchronization CLI Script
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
    'mode' => 'both',      // both, push, pull
    'type' => 'all',       // all, grades, enrollments, users
    'courseid' => null,    // specific course ID
    'term' => null,        // academic term
    'userid' => null,      // specific user ID
    'verbose' => false,    // verbose output
    'dry-run' => false,    // dry run mode
    'force' => false,      // force sync even if already running
    'config-check' => false // check configuration only
], [
    'h' => 'help',
    'm' => 'mode',
    't' => 'type',
    'c' => 'courseid',
    'T' => 'term',
    'u' => 'userid',
    'v' => 'verbose',
    'd' => 'dry-run',
    'f' => 'force',
    'C' => 'config-check'
]);

if ($options['help']) {
    echo "
SIS Synchronization Script

Usage:
    php sync_sis.php [OPTIONS]

Options:
    -h, --help              Show this help
    -m, --mode=MODE         Sync mode: both, push, pull (default: both)
    -t, --type=TYPE         Data type: all, grades, enrollments, users (default: all)
    -c, --courseid=ID       Specific course ID (for grade operations)
    -T, --term=TERM         Academic term filter (for enrollment operations)
    -u, --userid=ID         Specific user ID (for grade operations)
    -v, --verbose           Verbose output
    -d, --dry-run           Dry run mode (show what would be done)
    -f, --force             Force sync even if already running
    -C, --config-check      Check configuration and exit

Sync Types:
    all         - Sync users, enrollments, and grades (if course specified)
    grades      - Push/pull grades only (requires courseid for push)
    enrollments - Pull enrollments from SIS
    users       - Pull/update user data from SIS

Examples:
    # Basic sync (pull users and enrollments)
    php sync_sis.php --mode=pull --type=all

    # Push grades for specific course
    php sync_sis.php --mode=push --type=grades --courseid=123

    # Pull enrollments for specific term
    php sync_sis.php --mode=pull --type=enrollments --term='2025-Spring'

    # Dry run to see what would happen
    php sync_sis.php --dry-run --verbose

    # Check configuration
    php sync_sis.php --config-check

";
    exit(0);
}

/**
 * Check SIS configuration
 */
function check_sis_config($verbose = false) {
    $config_items = [
        'sis_enabled' => 'SIS Integration Enabled',
        'sis_url' => 'SIS API URL',
        'sis_api_key' => 'SIS API Key',
        'sis_timeout' => 'API Timeout'
    ];

    $all_good = true;

    mtrace("Checking SIS configuration...");

    foreach ($config_items as $key => $description) {
        $value = get_config('local_pucsr_api', $key);
        $status = 'OK';

        if (empty($value)) {
            $status = 'MISSING';
            $all_good = false;
        } elseif ($key === 'sis_enabled' && !$value) {
            $status = 'DISABLED';
            $all_good = false;
        }

        if ($verbose || $status !== 'OK') {
            $display_value = $key === 'sis_api_key' ? '[HIDDEN]' : $value;
            mtrace("  {$description}: {$display_value} [{$status}]");
        }
    }

    // Check database tables
    global $DB;
    $tables = [
        'local_pucsr_api_sync_log',
        'local_pucsr_api_sis_mapping',
        'local_pucsr_api_composite_config'
    ];

    mtrace("Checking database tables...");
    foreach ($tables as $table) {
        if ($DB->get_manager()->table_exists($table)) {
            if ($verbose) {
                $count = $DB->count_records($table);
                mtrace("  {$table}: OK ({$count} records)");
            }
        } else {
            mtrace("  {$table}: MISSING");
            $all_good = false;
        }
    }

    return $all_good;
}

/**
 * Validate sync parameters
 */
function validate_sync_params($options) {
    $errors = [];

    // Validate mode
    if (!in_array($options['mode'], ['both', 'push', 'pull'])) {
        $errors[] = "Invalid mode: {$options['mode']}";
    }

    // Validate type
    if (!in_array($options['type'], ['all', 'grades', 'enrollments', 'users'])) {
        $errors[] = "Invalid type: {$options['type']}";
    }

    // Validate course ID if provided
    if ($options['courseid'] && !is_numeric($options['courseid'])) {
        $errors[] = "Course ID must be numeric";
    }

    // Validate user ID if provided
    if ($options['userid'] && !is_numeric($options['userid'])) {
        $errors[] = "User ID must be numeric";
    }

    // Check requirements for grade operations
    if ($options['type'] === 'grades' && $options['mode'] === 'push' && !$options['courseid']) {
        $errors[] = "Course ID is required for pushing grades";
    }

    return $errors;
}

/**
 * Execute sync operation
 */
function execute_sync($options) {
    global $DB;

    try {
        mtrace("Initializing SIS integration...");
        $sis = new \local_pucsr_api\api\sis_integration();

        $results = [];
        $start_time = time();

        // Determine what operations to perform
        $operations = [];

        if ($options['type'] === 'all') {
            if ($options['mode'] === 'pull' || $options['mode'] === 'both') {
                $operations[] = ['type' => 'users', 'direction' => 'pull'];
                $operations[] = ['type' => 'enrollments', 'direction' => 'pull'];
            }
            if ($options['mode'] === 'push' || $options['mode'] === 'both') {
                if ($options['courseid']) {
                    $operations[] = ['type' => 'grades', 'direction' => 'push'];
                }
            }
        } else {
            if ($options['mode'] === 'both') {
                if ($options['type'] === 'grades') {
                    $operations[] = ['type' => 'grades', 'direction' => 'push'];
                } else {
                    $operations[] = ['type' => $options['type'], 'direction' => 'pull'];
                }
            } else {
                $operations[] = ['type' => $options['type'], 'direction' => $options['mode']];
            }
        }

        // Execute operations
        foreach ($operations as $operation) {
            $op_type = $operation['type'];
            $op_direction = $operation['direction'];

            mtrace("Starting {$op_direction} operation for {$op_type}...");

            if ($options['dry-run']) {
                mtrace("  [DRY RUN] Would execute: {$op_direction} {$op_type}");
                continue;
            }

            try {
                switch ($op_type) {
                    case 'users':
                        if ($op_direction === 'pull') {
                            $result = $sis->sync_users($options['userid'] ? [$options['userid']] : null);
                            mtrace("  Users: {$result['created']} created, {$result['updated']} updated");
                            if (!empty($result['errors'])) {
                                mtrace("  Errors: " . count($result['errors']));
                                if ($options['verbose']) {
                                    foreach ($result['errors'] as $error) {
                                        mtrace("    - {$error['email']}: {$error['error']}");
                                    }
                                }
                            }
                            $results['users'] = $result;
                        }
                        break;

                    case 'enrollments':
                        if ($op_direction === 'pull') {
                            $result = $sis->pull_enrollments($options['term']);
                            mtrace("  Enrollments: {$result['enrolled']} enrolled");
                            mtrace("  Courses processed: " . implode(', ', $result['courses_processed']));
                            if (!empty($result['errors'])) {
                                mtrace("  Errors: " . count($result['errors']));
                                if ($options['verbose']) {
                                    foreach ($result['errors'] as $error) {
                                        mtrace("    - {$error['student_id']}: {$error['error']}");
                                    }
                                }
                            }
                            $results['enrollments'] = $result;
                        }
                        break;

                    case 'grades':
                        if ($op_direction === 'push' && $options['courseid']) {
                            $result = $sis->push_grades($options['courseid'], $options['userid']);
                            mtrace("  Grades: {$result['count']} pushed");
                            if (!empty($result['errors'])) {
                                mtrace("  Errors: " . count($result['errors']));
                                if ($options['verbose']) {
                                    foreach ($result['errors'] as $error) {
                                        mtrace("    - {$error}");
                                    }
                                }
                            }
                            $results['grades'] = $result;
                        }
                        break;
                }

            } catch (Exception $e) {
                mtrace("  ERROR: " . $e->getMessage());
                $results[$op_type] = ['error' => $e->getMessage()];
            }
        }

        $duration = time() - $start_time;
        mtrace("Sync completed in {$duration} seconds");

        // Summary
        mtrace("\nSummary:");
        foreach ($results as $type => $result) {
            if (isset($result['error'])) {
                mtrace("  {$type}: FAILED - {$result['error']}");
            } else {
                switch ($type) {
                    case 'users':
                        mtrace("  {$type}: {$result['created']} created, {$result['updated']} updated");
                        break;
                    case 'enrollments':
                        mtrace("  {$type}: {$result['enrolled']} enrolled");
                        break;
                    case 'grades':
                        mtrace("  {$type}: {$result['count']} pushed");
                        break;
                }
            }
        }

        return true;

    } catch (Exception $e) {
        mtrace("FATAL ERROR: " . $e->getMessage());
        if ($options['verbose']) {
            mtrace("Stack trace:");
            mtrace($e->getTraceAsString());
        }
        return false;
    }
}

// Main execution
mtrace("PUCSR SIS Synchronization Tool");
mtrace("==============================");

// Configuration check
if ($options['config-check']) {
    $config_ok = check_sis_config(true);
    exit($config_ok ? 0 : 1);
}

// Quick config check
if (!check_sis_config()) {
    mtrace("Configuration errors found. Use --config-check for details.");
    exit(1);
}

// Validate parameters
$errors = validate_sync_params($options);
if (!empty($errors)) {
    mtrace("Parameter errors:");
    foreach ($errors as $error) {
        mtrace("  - {$error}");
    }
    exit(1);
}

// Show what will be done
if ($options['verbose'] || $options['dry-run']) {
    mtrace("Configuration:");
    mtrace("  Mode: {$options['mode']}");
    mtrace("  Type: {$options['type']}");
    if ($options['courseid']) {
        mtrace("  Course ID: {$options['courseid']}");
    }
    if ($options['term']) {
        mtrace("  Term: {$options['term']}");
    }
    if ($options['userid']) {
        mtrace("  User ID: {$options['userid']}");
    }
    mtrace("");
}

// Execute sync
$success = execute_sync($options);

exit($success ? 0 : 1);