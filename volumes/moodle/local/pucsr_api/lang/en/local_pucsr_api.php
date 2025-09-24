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
 * PUCSR API plugin language strings
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

$string['pluginname'] = 'PUCSR API';
$string['pucsr_api:sync_sis'] = 'Synchronize with SIS system';
$string['pucsr_api:push_grades'] = 'Push grades to SIS';
$string['pucsr_api:pull_enrollments'] = 'Pull enrollments from SIS';
$string['pucsr_api:manage_composite'] = 'Manage composite grade structures';
$string['pucsr_api:view_composite'] = 'View composite grades';
$string['pucsr_api:view_logs'] = 'View synchronization logs';
$string['pucsr_api:view_analytics'] = 'View course analytics';
$string['pucsr_api:configure'] = 'Configure PUCSR API settings';
$string['pucsr_api:use_api'] = 'Use PUCSR API services';

// Settings
$string['settings'] = 'PUCSR API Settings';
$string['sis_url'] = 'SIS API URL';
$string['sis_url_desc'] = 'Base URL for the Student Information System API';
$string['sis_api_key'] = 'SIS API Key';
$string['sis_api_key_desc'] = 'API key for authenticating with the SIS system';
$string['sis_timeout'] = 'SIS API Timeout';
$string['sis_timeout_desc'] = 'Timeout in seconds for SIS API requests (default: 30)';
$string['sis_enabled'] = 'Enable SIS Integration';
$string['sis_enabled_desc'] = 'Enable synchronization with Student Information System';
$string['default_sync_interval'] = 'Default Sync Interval';
$string['default_sync_interval_desc'] = 'Default interval in minutes for automatic synchronization (0 to disable)';

// Composite Grades
$string['composite_structure'] = 'Composite Grade Structure';
$string['composite_grammar'] = 'Grammar Component';
$string['composite_writing'] = 'Writing Component';
$string['composite_speaking'] = 'Speaking Component';
$string['composite_listening'] = 'Listening Component';
$string['composite_reading'] = 'Reading Component';
$string['composite_total'] = 'Composite Total';
$string['create_structure'] = 'Create Grade Structure';
$string['structure_created'] = 'Grade structure created successfully';
$string['structure_exists'] = 'A composite structure already exists for this course';

// IEAP Course Structures
$string['ieap1_structure'] = 'IEAP-1 Grade Structure (Beginner)';
$string['ieap2_structure'] = 'IEAP-2 Grade Structure (Elementary)';
$string['ieap3_structure'] = 'IEAP-3 Grade Structure (Pre-Intermediate)';
$string['ieap4_structure'] = 'IEAP-4 Grade Structure (Intermediate)';
$string['ieap5_structure'] = 'IEAP-5 Grade Structure (Upper-Intermediate)';
$string['ieap6_structure'] = 'IEAP-6 Grade Structure (Advanced)';
$string['auto_detect_ieap'] = 'Auto-detect IEAP level';
$string['auto_detect_ieap_desc'] = 'Automatically detect IEAP level from course name';
$string['ieap_level_detected'] = 'IEAP level detected: {$a}';
$string['ieap_level_not_detected'] = 'Could not detect IEAP level from course name';
$string['invalid_ieap_level'] = 'Invalid IEAP level: {$a}';
$string['invalid_ieap_template'] = 'Invalid IEAP template: {$a}';

// SIS Sync Messages
$string['sync_success'] = 'Synchronization completed successfully';
$string['sync_partial'] = 'Synchronization completed with some errors';
$string['sync_failed'] = 'Synchronization failed';
$string['grades_pushed'] = 'Grades pushed to SIS: {$a}';
$string['enrollments_pulled'] = 'Enrollments pulled from SIS: {$a}';
$string['sync_in_progress'] = 'Synchronization is already in progress';

// Error Messages
$string['error_creating_structure'] = 'Error creating grade structure: {$a}';
$string['error_sis_connection'] = 'Could not connect to SIS system: {$a}';
$string['error_invalid_course'] = 'Invalid course ID';
$string['error_permission_denied'] = 'Permission denied';
$string['error_invalid_data'] = 'Invalid data provided';
$string['error_missing_config'] = 'Missing configuration: {$a}';

// API Messages
$string['api_token_required'] = 'API token is required';
$string['api_invalid_token'] = 'Invalid API token';
$string['api_rate_limit'] = 'API rate limit exceeded';
$string['api_maintenance'] = 'API is currently under maintenance';

// Logging
$string['log_sync_started'] = 'SIS sync started: {$a}';
$string['log_sync_completed'] = 'SIS sync completed: {$a}';
$string['log_grades_pushed'] = 'Grades pushed to SIS for course {$a}';
$string['log_enrollments_pulled'] = 'Enrollments pulled from SIS for term {$a}';
$string['log_structure_created'] = 'Composite structure created for course {$a}';

// Privacy
$string['privacy:metadata'] = 'The PUCSR API plugin does not store any personal data itself, but may transmit user data to external SIS systems.';
$string['privacy:metadata:sis'] = 'User data sent to Student Information System';
$string['privacy:metadata:sis:userid'] = 'User ID from Moodle';
$string['privacy:metadata:sis:grades'] = 'User grades from courses';
$string['privacy:metadata:sis:enrollment'] = 'User enrollment information';