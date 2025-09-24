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
 * SIS Integration API
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_pucsr_api\api;

use moodle_exception;

/**
 * Main class for SIS integration operations
 */
class sis_integration {

    /** @var string SIS API base URL */
    private $sis_api_url;

    /** @var string API authentication key */
    private $api_key;

    /** @var int API timeout in seconds */
    private $timeout;

    /** @var bool Debug mode flag */
    private $debug_mode;

    /**
     * Constructor
     */
    public function __construct() {
        $this->sis_api_url = get_config('local_pucsr_api', 'sis_url');
        $this->api_key = get_config('local_pucsr_api', 'sis_api_key');
        $this->timeout = get_config('local_pucsr_api', 'sis_timeout') ?: 30;
        $this->debug_mode = get_config('local_pucsr_api', 'debug_mode');

        if (empty($this->sis_api_url) || empty($this->api_key)) {
            throw new moodle_exception('error_missing_config', 'local_pucsr_api', '', 'SIS URL or API key');
        }
    }

    /**
     * Push grades to SIS system
     *
     * @param int $courseid Course ID
     * @param int|null $userid Specific user ID (optional)
     * @return array Push results
     */
    public function push_grades($courseid, $userid = null) {
        global $DB;

        // Get composite grades for the course
        $grades = $this->get_composite_grades($courseid, $userid);

        if (empty($grades)) {
            return ['success' => true, 'count' => 0, 'message' => 'No grades to push'];
        }

        // Transform grades for SIS format
        $payload = [
            'action' => 'import_grades',
            'course_code' => $this->get_sis_course_code($courseid),
            'timestamp' => time(),
            'grades' => []
        ];

        foreach ($grades as $grade) {
            $sis_student_id = $this->get_sis_student_id($grade->userid);
            if (!$sis_student_id) {
                continue; // Skip if no SIS mapping
            }

            $grade_data = [
                'student_id' => $sis_student_id,
                'student_email' => $grade->email,
                'composite_grade' => $grade->composite_grade
            ];

            // Add component breakdown if available
            if (isset($grade->components)) {
                $grade_data['components'] = [];
                foreach ($grade->components as $component) {
                    $grade_data['components'][$component->name] = [
                        'grade' => $component->component_grade,
                        'weight' => $component->weight,
                        'items' => []
                    ];

                    foreach ($component->items as $item) {
                        $grade_data['components'][$component->name]['items'][] = [
                            'name' => $item->name,
                            'grade' => $item->grade,
                            'max_grade' => $item->maxgrade,
                            'percentage' => $item->percentage
                        ];
                    }
                }
            }

            $payload['grades'][] = $grade_data;
        }

        // Send to SIS
        try {
            $response = $this->call_sis_api('POST', '/api/grades/import', $payload);

            // Log the sync
            $this->log_sync('grades', $courseid, 'push', count($payload['grades']),
                count($response['success'] ?? []), count($response['errors'] ?? []),
                $response['success'] ? 'success' : 'partial');

            return [
                'success' => true,
                'count' => count($payload['grades']),
                'sis_response' => $response,
                'errors' => $response['errors'] ?? []
            ];

        } catch (\Exception $e) {
            $this->log_sync('grades', $courseid, 'push', count($payload['grades']), 0,
                count($payload['grades']), 'failed', $e->getMessage());

            throw new moodle_exception('error_sis_connection', 'local_pucsr_api', '', $e->getMessage());
        }
    }

    /**
     * Pull enrollments from SIS system
     *
     * @param string|null $term Academic term filter
     * @param string|null $course_code Specific course code
     * @return array Pull results
     */
    public function pull_enrollments($term = null, $course_code = null) {
        global $DB, $CFG;
        require_once($CFG->dirroot . '/enrol/manual/locallib.php');

        $endpoint = '/api/enrollments';
        $params = [];

        if ($term) {
            $params['term'] = $term;
        }
        if ($course_code) {
            $params['course_code'] = $course_code;
        }

        if (!empty($params)) {
            $endpoint .= '?' . http_build_query($params);
        }

        try {
            $response = $this->call_sis_api('GET', $endpoint);

            $results = [
                'enrolled' => 0,
                'updated' => 0,
                'errors' => [],
                'courses_processed' => []
            ];

            foreach ($response['enrollments'] as $enrollment) {
                try {
                    $this->process_enrollment($enrollment);
                    $results['enrolled']++;

                    if (!in_array($enrollment['course_code'], $results['courses_processed'])) {
                        $results['courses_processed'][] = $enrollment['course_code'];
                    }

                } catch (\Exception $e) {
                    $results['errors'][] = [
                        'student_id' => $enrollment['student_id'],
                        'course_code' => $enrollment['course_code'],
                        'error' => $e->getMessage()
                    ];
                }
            }

            // Log the sync
            $this->log_sync('enrollments', null, 'pull', count($response['enrollments']),
                $results['enrolled'], count($results['errors']),
                empty($results['errors']) ? 'success' : 'partial');

            return $results;

        } catch (\Exception $e) {
            $this->log_sync('enrollments', null, 'pull', 0, 0, 0, 'failed', $e->getMessage());
            throw new moodle_exception('error_sis_connection', 'local_pucsr_api', '', $e->getMessage());
        }
    }

    /**
     * Sync users from SIS
     *
     * @param array $user_ids Specific user IDs to sync (optional)
     * @return array Sync results
     */
    public function sync_users($user_ids = null) {
        global $DB, $CFG;
        require_once($CFG->dirroot . '/user/lib.php');

        $endpoint = '/api/users';
        if ($user_ids) {
            $endpoint .= '?' . http_build_query(['user_ids' => implode(',', $user_ids)]);
        }

        try {
            $response = $this->call_sis_api('GET', $endpoint);

            $results = [
                'created' => 0,
                'updated' => 0,
                'errors' => []
            ];

            foreach ($response['users'] as $sis_user) {
                try {
                    $result = $this->process_user($sis_user);
                    $results[$result]++;
                } catch (\Exception $e) {
                    $results['errors'][] = [
                        'sis_id' => $sis_user['id'],
                        'email' => $sis_user['email'],
                        'error' => $e->getMessage()
                    ];
                }
            }

            $this->log_sync('users', null, 'pull', count($response['users']),
                $results['created'] + $results['updated'], count($results['errors']),
                empty($results['errors']) ? 'success' : 'partial');

            return $results;

        } catch (\Exception $e) {
            $this->log_sync('users', null, 'pull', 0, 0, 0, 'failed', $e->getMessage());
            throw new moodle_exception('error_sis_connection', 'local_pucsr_api', '', $e->getMessage());
        }
    }

    /**
     * Get composite grades for a course
     *
     * @param int $courseid Course ID
     * @param int|null $userid User ID
     * @return array Grade data
     */
    private function get_composite_grades($courseid, $userid = null) {
        global $DB, $CFG;
        require_once($CFG->libdir . '/gradelib.php');

        // Use the composite external API
        $composite_api = new \local_pucsr_api\external\composite_external();
        $result = $composite_api->get_composite_grades($courseid, $userid, true);

        return $result['grades'];
    }

    /**
     * Process enrollment from SIS
     *
     * @param array $enrollment Enrollment data from SIS
     */
    private function process_enrollment($enrollment) {
        global $DB, $CFG;

        // Find or create user
        $user = $this->find_or_create_user($enrollment['student']);

        // Find course by SIS code
        $courseid = $this->get_moodle_course_id($enrollment['course_code']);
        if (!$courseid) {
            throw new \Exception("Course not found for code: {$enrollment['course_code']}");
        }

        // Get manual enrollment plugin
        $enrol_plugin = enrol_get_plugin('manual');
        if (!$enrol_plugin) {
            throw new \Exception('Manual enrollment plugin not available');
        }

        // Get enrollment instance
        $instance = $DB->get_record('enrol', [
            'courseid' => $courseid,
            'enrol' => 'manual'
        ], '*', IGNORE_MULTIPLE);

        if (!$instance) {
            throw new \Exception("No manual enrollment instance for course: {$enrollment['course_code']}");
        }

        // Check if already enrolled
        if (!$DB->record_exists('user_enrolments', [
            'enrolid' => $instance->id,
            'userid' => $user->id
        ])) {
            // Enroll user
            $roleid = $DB->get_field('role', 'id', ['shortname' => 'student']);
            $enrol_plugin->enrol_user($instance, $user->id, $roleid);

            // Update SIS mapping
            $this->update_sis_mapping('user', $user->id, $enrollment['student']['id']);
        }
    }

    /**
     * Process user from SIS
     *
     * @param array $sis_user User data from SIS
     * @return string 'created' or 'updated'
     */
    private function process_user($sis_user) {
        global $DB, $CFG;

        // Check if user exists
        $user = $DB->get_record('user', ['email' => $sis_user['email']]);

        if ($user) {
            // Update existing user
            $user->firstname = $sis_user['first_name'];
            $user->lastname = $sis_user['last_name'];
            $user->timemodified = time();

            $DB->update_record('user', $user);
            $this->update_sis_mapping('user', $user->id, $sis_user['id']);

            return 'updated';
        } else {
            // Create new user
            $new_user = [
                'auth' => 'manual',
                'confirmed' => 1,
                'mnethostid' => $CFG->mnet_localhost_id,
                'email' => $sis_user['email'],
                'username' => $sis_user['username'] ?? $sis_user['email'],
                'firstname' => $sis_user['first_name'],
                'lastname' => $sis_user['last_name'],
                'lang' => $CFG->lang,
                'timecreated' => time(),
                'timemodified' => time()
            ];

            $userid = $DB->insert_record('user', $new_user);
            $this->update_sis_mapping('user', $userid, $sis_user['id']);

            return 'created';
        }
    }

    /**
     * Find or create user from SIS data
     *
     * @param array $student_data Student data
     * @return object User object
     */
    private function find_or_create_user($student_data) {
        global $DB;

        // Try to find by email first
        $user = $DB->get_record('user', ['email' => $student_data['email']]);

        if (!$user) {
            // Try to find by SIS mapping
            $mapping = $DB->get_record('local_pucsr_api_sis_mapping', [
                'entity_type' => 'user',
                'sis_id' => $student_data['id'],
                'active' => 1
            ]);

            if ($mapping) {
                $user = $DB->get_record('user', ['id' => $mapping->moodle_id]);
            }
        }

        if (!$user) {
            // Create user if not found
            $result = $this->process_user([
                'id' => $student_data['id'],
                'email' => $student_data['email'],
                'first_name' => $student_data['first_name'],
                'last_name' => $student_data['last_name'],
                'username' => $student_data['username'] ?? $student_data['email']
            ]);

            $user = $DB->get_record('user', ['email' => $student_data['email']]);
        }

        return $user;
    }

    /**
     * Make API call to SIS system
     *
     * @param string $method HTTP method
     * @param string $endpoint API endpoint
     * @param array|null $data Request data
     * @return array Response data
     */
    private function call_sis_api($method, $endpoint, $data = null) {
        $url = rtrim($this->sis_api_url, '/') . $endpoint;

        $ch = curl_init($url);

        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_TIMEOUT, $this->timeout);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Authorization: Bearer ' . $this->api_key,
            'Content-Type: application/json',
            'User-Agent: Moodle-PUCSR-API/1.0'
        ]);

        if ($data) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }

        if ($this->debug_mode) {
            mtrace("SIS API Call: {$method} {$url}");
            if ($data) {
                mtrace("Request data: " . json_encode($data, JSON_PRETTY_PRINT));
            }
        }

        $response = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($error) {
            throw new \Exception("cURL error: {$error}");
        }

        if ($http_code < 200 || $http_code >= 300) {
            throw new \Exception("HTTP {$http_code}: {$response}");
        }

        $decoded = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new \Exception("Invalid JSON response: " . json_last_error_msg());
        }

        if ($this->debug_mode) {
            mtrace("Response: " . json_encode($decoded, JSON_PRETTY_PRINT));
        }

        return $decoded;
    }

    /**
     * Get SIS student ID for Moodle user
     *
     * @param int $userid Moodle user ID
     * @return string|null SIS student ID
     */
    private function get_sis_student_id($userid) {
        global $DB;

        $mapping = $DB->get_record('local_pucsr_api_sis_mapping', [
            'entity_type' => 'user',
            'moodle_id' => $userid,
            'active' => 1
        ]);

        return $mapping ? $mapping->sis_id : null;
    }

    /**
     * Get SIS course code for Moodle course
     *
     * @param int $courseid Moodle course ID
     * @return string|null SIS course code
     */
    private function get_sis_course_code($courseid) {
        global $DB;

        $mapping = $DB->get_record('local_pucsr_api_sis_mapping', [
            'entity_type' => 'course',
            'moodle_id' => $courseid,
            'active' => 1
        ]);

        return $mapping ? $mapping->sis_code : null;
    }

    /**
     * Get Moodle course ID from SIS course code
     *
     * @param string $course_code SIS course code
     * @return int|null Moodle course ID
     */
    private function get_moodle_course_id($course_code) {
        global $DB;

        $mapping = $DB->get_record('local_pucsr_api_sis_mapping', [
            'entity_type' => 'course',
            'sis_code' => $course_code,
            'active' => 1
        ]);

        return $mapping ? $mapping->moodle_id : null;
    }

    /**
     * Update SIS mapping record
     *
     * @param string $entity_type Entity type (user, course, category)
     * @param int $moodle_id Moodle entity ID
     * @param string $sis_id SIS entity ID
     * @param string|null $sis_code SIS code (optional)
     */
    private function update_sis_mapping($entity_type, $moodle_id, $sis_id, $sis_code = null) {
        global $DB;

        $mapping = $DB->get_record('local_pucsr_api_sis_mapping', [
            'entity_type' => $entity_type,
            'moodle_id' => $moodle_id
        ]);

        if ($mapping) {
            $mapping->sis_id = $sis_id;
            $mapping->sis_code = $sis_code;
            $mapping->timemodified = time();
            $DB->update_record('local_pucsr_api_sis_mapping', $mapping);
        } else {
            $mapping = [
                'entity_type' => $entity_type,
                'moodle_id' => $moodle_id,
                'sis_id' => $sis_id,
                'sis_code' => $sis_code,
                'active' => 1,
                'timecreated' => time(),
                'timemodified' => time()
            ];
            $DB->insert_record('local_pucsr_api_sis_mapping', $mapping);
        }
    }

    /**
     * Log synchronization operation
     *
     * @param string $sync_type Type of sync
     * @param int|null $courseid Course ID
     * @param string $direction push or pull
     * @param int $processed Number of records processed
     * @param int $success Number of successful records
     * @param int $failed Number of failed records
     * @param string $status Overall status
     * @param string|null $error_message Error message
     */
    private function log_sync($sync_type, $courseid, $direction, $processed, $success, $failed, $status, $error_message = null) {
        global $DB;

        $log_record = [
            'sync_type' => $sync_type,
            'courseid' => $courseid,
            'direction' => $direction,
            'records_processed' => $processed,
            'records_success' => $success,
            'records_failed' => $failed,
            'status' => $status,
            'error_message' => $error_message,
            'timecreated' => time(),
            'timemodified' => time()
        ];

        $DB->insert_record('local_pucsr_api_sync_log', $log_record);
    }
}