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
 * PUCSR API web service definitions
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

$functions = [
    // Composite Grades Management
    'local_pucsr_api_create_composite_structure' => [
        'classname'   => 'local_pucsr_api\external\composite_external',
        'methodname'  => 'create_composite_structure',
        'classpath'   => 'local/pucsr_api/classes/external/composite_external.php',
        'description' => 'Create IEAP-4 style composite grade structure',
        'type'        => 'write',
        'ajax'        => true,
        'capabilities'=> 'moodle/grade:manage',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_get_composite_grades' => [
        'classname'   => 'local_pucsr_api\external\composite_external',
        'methodname'  => 'get_composite_grades',
        'classpath'   => 'local/pucsr_api/classes/external/composite_external.php',
        'description' => 'Get student composite grades with breakdown',
        'type'        => 'read',
        'ajax'        => true,
        'capabilities'=> 'moodle/grade:view',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_update_composite_grades' => [
        'classname'   => 'local_pucsr_api\external\composite_external',
        'methodname'  => 'update_composite_grades',
        'classpath'   => 'local/pucsr_api/classes/external/composite_external.php',
        'description' => 'Update grades in composite structure',
        'type'        => 'write',
        'ajax'        => true,
        'capabilities'=> 'moodle/grade:edit',
        'services'    => ['pucsr_api_service']
    ],

    // Bulk Operations
    'local_pucsr_api_bulk_enroll' => [
        'classname'   => 'local_pucsr_api\external\enrollment_external',
        'methodname'  => 'bulk_enroll',
        'classpath'   => 'local/pucsr_api/classes/external/enrollment_external.php',
        'description' => 'Bulk enroll students from SIS',
        'type'        => 'write',
        'capabilities'=> 'enrol/manual:enrol',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_bulk_unenroll' => [
        'classname'   => 'local_pucsr_api\external\enrollment_external',
        'methodname'  => 'bulk_unenroll',
        'classpath'   => 'local/pucsr_api/classes/external/enrollment_external.php',
        'description' => 'Bulk unenroll students',
        'type'        => 'write',
        'capabilities'=> 'enrol/manual:unenrol',
        'services'    => ['pucsr_api_service']
    ],

    // SIS Sync
    'local_pucsr_api_sync_sis_data' => [
        'classname'   => 'local_pucsr_api\external\sis_external',
        'methodname'  => 'sync_data',
        'classpath'   => 'local/pucsr_api/classes/external/sis_external.php',
        'description' => 'Sync data between Moodle and SIS',
        'type'        => 'write',
        'capabilities'=> 'local/pucsr_api:sync_sis',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_push_grades_to_sis' => [
        'classname'   => 'local_pucsr_api\external\sis_external',
        'methodname'  => 'push_grades',
        'classpath'   => 'local/pucsr_api/classes/external/sis_external.php',
        'description' => 'Push grades to SIS system',
        'type'        => 'write',
        'capabilities'=> 'local/pucsr_api:push_grades',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_pull_enrollments_from_sis' => [
        'classname'   => 'local_pucsr_api\external\sis_external',
        'methodname'  => 'pull_enrollments',
        'classpath'   => 'local/pucsr_api/classes/external/sis_external.php',
        'description' => 'Pull enrollments from SIS system',
        'type'        => 'write',
        'capabilities'=> 'local/pucsr_api:pull_enrollments',
        'services'    => ['pucsr_api_service']
    ],

    // Reporting and Analytics
    'local_pucsr_api_get_course_analytics' => [
        'classname'   => 'local_pucsr_api\external\reports_external',
        'methodname'  => 'get_course_analytics',
        'classpath'   => 'local/pucsr_api/classes/external/reports_external.php',
        'description' => 'Get comprehensive course analytics',
        'type'        => 'read',
        'ajax'        => true,
        'capabilities'=> 'moodle/course:viewparticipants',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_get_sync_logs' => [
        'classname'   => 'local_pucsr_api\external\reports_external',
        'methodname'  => 'get_sync_logs',
        'classpath'   => 'local/pucsr_api/classes/external/reports_external.php',
        'description' => 'Get SIS synchronization logs',
        'type'        => 'read',
        'ajax'        => true,
        'capabilities'=> 'local/pucsr_api:view_logs',
        'services'    => ['pucsr_api_service']
    ],

    // IEAP Template Management
    'local_pucsr_api_get_ieap_templates' => [
        'classname'   => 'local_pucsr_api\external\composite_external',
        'methodname'  => 'get_ieap_templates',
        'classpath'   => 'local/pucsr_api/classes/external/composite_external.php',
        'description' => 'Get available IEAP course templates',
        'type'        => 'read',
        'ajax'        => true,
        'capabilities'=> 'local/pucsr_api:view_composite',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_detect_ieap_level' => [
        'classname'   => 'local_pucsr_api\external\composite_external',
        'methodname'  => 'detect_ieap_level',
        'classpath'   => 'local/pucsr_api/classes/external/composite_external.php',
        'description' => 'Detect IEAP level from course information',
        'type'        => 'read',
        'ajax'        => true,
        'capabilities'=> 'moodle/course:view',
        'services'    => ['pucsr_api_service']
    ],

    'local_pucsr_api_create_ieap_structure' => [
        'classname'   => 'local_pucsr_api\external\composite_external',
        'methodname'  => 'create_ieap_structure',
        'classpath'   => 'local/pucsr_api/classes/external/composite_external.php',
        'description' => 'Create IEAP grade structure using templates',
        'type'        => 'write',
        'ajax'        => true,
        'capabilities'=> 'moodle/grade:manage',
        'services'    => ['pucsr_api_service']
    ]
];

$services = [
    'PUCSR API Service' => [
        'functions' => [
            'local_pucsr_api_create_composite_structure',
            'local_pucsr_api_get_composite_grades',
            'local_pucsr_api_update_composite_grades',
            'local_pucsr_api_bulk_enroll',
            'local_pucsr_api_bulk_unenroll',
            'local_pucsr_api_sync_sis_data',
            'local_pucsr_api_push_grades_to_sis',
            'local_pucsr_api_pull_enrollments_from_sis',
            'local_pucsr_api_get_course_analytics',
            'local_pucsr_api_get_sync_logs',
            'local_pucsr_api_get_ieap_templates',
            'local_pucsr_api_detect_ieap_level',
            'local_pucsr_api_create_ieap_structure'
        ],
        'restrictedusers' => 1,
        'enabled' => 1,
        'shortname' => 'pucsr_api_service',
        'downloadfiles' => 0,
        'uploadfiles' => 0
    ]
];