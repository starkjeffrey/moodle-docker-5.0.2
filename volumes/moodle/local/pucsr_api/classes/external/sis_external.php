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
 * External API for SIS integration
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_pucsr_api\external;

use external_api;
use external_function_parameters;
use external_value;
use external_single_structure;
use external_multiple_structure;
use context_system;
use context_course;
use moodle_exception;

/**
 * External API for SIS integration operations
 */
class sis_external extends external_api {

    /**
     * Parameters for sync_data
     */
    public static function sync_data_parameters() {
        return new external_function_parameters([
            'sync_type' => new external_value(PARAM_TEXT, 'Type of sync: grades, enrollments, users, all'),
            'direction' => new external_value(PARAM_TEXT, 'Direction: push, pull, both'),
            'courseid' => new external_value(PARAM_INT, 'Course ID (optional for course-specific sync)', VALUE_DEFAULT, null),
            'term' => new external_value(PARAM_TEXT, 'Academic term (optional)', VALUE_DEFAULT, null),
            'force' => new external_value(PARAM_BOOL, 'Force sync even if already running', VALUE_DEFAULT, false)
        ]);
    }

    /**
     * Sync data between Moodle and SIS
     */
    public static function sync_data($sync_type, $direction, $courseid = null, $term = null, $force = false) {
        global $DB;

        // Validate parameters
        $params = self::validate_parameters(
            self::sync_data_parameters(),
            [
                'sync_type' => $sync_type,
                'direction' => $direction,
                'courseid' => $courseid,
                'term' => $term,
                'force' => $force
            ]
        );

        // Validate context and capabilities
        if ($courseid) {
            $context = context_course::instance($courseid);
            self::validate_context($context);
        } else {
            $context = context_system::instance();
            self::validate_context($context);
        }

        require_capability('local/pucsr_api:sync_sis', $context);

        // Check if SIS integration is enabled
        if (!get_config('local_pucsr_api', 'sis_enabled')) {
            throw new moodle_exception('sis_not_enabled', 'local_pucsr_api');
        }

        // Check for concurrent sync (unless forced)
        if (!$force) {
            $recent_sync = $DB->get_record_sql(
                "SELECT * FROM {local_pucsr_api_sync_log}
                 WHERE sync_type = ? AND status = 'running' AND timecreated > ?",
                [$sync_type, time() - 3600] // Check for running syncs in last hour
            );

            if ($recent_sync) {
                throw new moodle_exception('sync_in_progress', 'local_pucsr_api');
            }
        }

        $sis = new \local_pucsr_api\api\sis_integration();
        $results = [];

        try {
            switch ($sync_type) {
                case 'grades':
                    if ($direction === 'push' || $direction === 'both') {
                        if (!$courseid) {
                            throw new moodle_exception('courseid_required_for_grades', 'local_pucsr_api');
                        }
                        $results['push_grades'] = $sis->push_grades($courseid);
                    }
                    break;

                case 'enrollments':
                    if ($direction === 'pull' || $direction === 'both') {
                        $results['pull_enrollments'] = $sis->pull_enrollments($term);
                    }
                    break;

                case 'users':
                    if ($direction === 'pull' || $direction === 'both') {
                        $results['sync_users'] = $sis->sync_users();
                    }
                    break;

                case 'all':
                    if ($direction === 'pull' || $direction === 'both') {
                        $results['sync_users'] = $sis->sync_users();
                        $results['pull_enrollments'] = $sis->pull_enrollments($term);
                    }
                    if ($direction === 'push' || $direction === 'both') {
                        if ($courseid) {
                            $results['push_grades'] = $sis->push_grades($courseid);
                        }
                    }
                    break;

                default:
                    throw new moodle_exception('invalid_sync_type', 'local_pucsr_api', '', $sync_type);
            }

            return [
                'success' => true,
                'sync_type' => $sync_type,
                'direction' => $direction,
                'results' => $results
            ];

        } catch (\Exception $e) {
            return [
                'success' => false,
                'sync_type' => $sync_type,
                'direction' => $direction,
                'error' => $e->getMessage(),
                'results' => $results
            ];
        }
    }

    /**
     * Return description for sync_data
     */
    public static function sync_data_returns() {
        return new external_single_structure([
            'success' => new external_value(PARAM_BOOL, 'Operation success'),
            'sync_type' => new external_value(PARAM_TEXT, 'Type of sync performed'),
            'direction' => new external_value(PARAM_TEXT, 'Direction of sync'),
            'error' => new external_value(PARAM_TEXT, 'Error message if failed', VALUE_OPTIONAL),
            'results' => new external_single_structure([
                'push_grades' => new external_single_structure([
                    'success' => new external_value(PARAM_BOOL, 'Push success'),
                    'count' => new external_value(PARAM_INT, 'Number of grades pushed'),
                    'errors' => new external_multiple_structure(
                        new external_value(PARAM_TEXT, 'Error message'), VALUE_OPTIONAL
                    )
                ], VALUE_OPTIONAL),
                'pull_enrollments' => new external_single_structure([
                    'enrolled' => new external_value(PARAM_INT, 'Number enrolled'),
                    'updated' => new external_value(PARAM_INT, 'Number updated'),
                    'errors' => new external_multiple_structure(
                        new external_single_structure([
                            'student_id' => new external_value(PARAM_TEXT, 'Student ID'),
                            'error' => new external_value(PARAM_TEXT, 'Error message')
                        ])
                    )
                ], VALUE_OPTIONAL),
                'sync_users' => new external_single_structure([
                    'created' => new external_value(PARAM_INT, 'Number created'),
                    'updated' => new external_value(PARAM_INT, 'Number updated'),
                    'errors' => new external_multiple_structure(
                        new external_single_structure([
                            'sis_id' => new external_value(PARAM_TEXT, 'SIS user ID'),
                            'error' => new external_value(PARAM_TEXT, 'Error message')
                        ])
                    )
                ], VALUE_OPTIONAL)
            ])
        ]);
    }

    /**
     * Parameters for push_grades
     */
    public static function push_grades_parameters() {
        return new external_function_parameters([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'userid' => new external_value(PARAM_INT, 'User ID (optional)', VALUE_DEFAULT, null)
        ]);
    }

    /**
     * Push grades to SIS
     */
    public static function push_grades($courseid, $userid = null) {
        // Validate parameters
        $params = self::validate_parameters(
            self::push_grades_parameters(),
            ['courseid' => $courseid, 'userid' => $userid]
        );

        // Validate context
        $context = context_course::instance($courseid);
        self::validate_context($context);
        require_capability('local/pucsr_api:push_grades', $context);

        $sis = new \local_pucsr_api\api\sis_integration();
        return $sis->push_grades($courseid, $userid);
    }

    /**
     * Return description for push_grades
     */
    public static function push_grades_returns() {
        return new external_single_structure([
            'success' => new external_value(PARAM_BOOL, 'Push success'),
            'count' => new external_value(PARAM_INT, 'Number of grades pushed'),
            'message' => new external_value(PARAM_TEXT, 'Status message', VALUE_OPTIONAL),
            'errors' => new external_multiple_structure(
                new external_value(PARAM_TEXT, 'Error message'), VALUE_OPTIONAL
            )
        ]);
    }

    /**
     * Parameters for pull_enrollments
     */
    public static function pull_enrollments_parameters() {
        return new external_function_parameters([
            'term' => new external_value(PARAM_TEXT, 'Academic term (optional)', VALUE_DEFAULT, null),
            'course_code' => new external_value(PARAM_TEXT, 'Course code (optional)', VALUE_DEFAULT, null)
        ]);
    }

    /**
     * Pull enrollments from SIS
     */
    public static function pull_enrollments($term = null, $course_code = null) {
        // Validate parameters
        $params = self::validate_parameters(
            self::pull_enrollments_parameters(),
            ['term' => $term, 'course_code' => $course_code]
        );

        // Validate context
        $context = context_system::instance();
        self::validate_context($context);
        require_capability('local/pucsr_api:pull_enrollments', $context);

        $sis = new \local_pucsr_api\api\sis_integration();
        return $sis->pull_enrollments($term, $course_code);
    }

    /**
     * Return description for pull_enrollments
     */
    public static function pull_enrollments_returns() {
        return new external_single_structure([
            'enrolled' => new external_value(PARAM_INT, 'Number enrolled'),
            'updated' => new external_value(PARAM_INT, 'Number updated'),
            'courses_processed' => new external_multiple_structure(
                new external_value(PARAM_TEXT, 'Course code')
            ),
            'errors' => new external_multiple_structure(
                new external_single_structure([
                    'student_id' => new external_value(PARAM_TEXT, 'Student ID'),
                    'course_code' => new external_value(PARAM_TEXT, 'Course code'),
                    'error' => new external_value(PARAM_TEXT, 'Error message')
                ])
            )
        ]);
    }
}