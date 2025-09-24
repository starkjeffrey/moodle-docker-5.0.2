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
 * Unit tests for SIS integration functionality
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_pucsr_api;

use advanced_testcase;

/**
 * Test SIS integration functionality
 */
class sis_integration_test extends advanced_testcase {

    /** @var object Test course */
    private $course;

    /** @var object Test user */
    private $user;

    /**
     * Set up test environment
     */
    protected function setUp(): void {
        $this->resetAfterTest();

        // Create test course
        $this->course = $this->getDataGenerator()->create_course([
            'shortname' => 'SIS_TEST',
            'fullname' => 'SIS Integration Test Course'
        ]);

        // Create test user
        $this->user = $this->getDataGenerator()->create_user([
            'firstname' => 'SIS',
            'lastname' => 'User',
            'email' => 'sis.user@test.com'
        ]);

        // Set up test configuration
        set_config('sis_enabled', 1, 'local_pucsr_api');
        set_config('sis_url', 'https://sis.test.api', 'local_pucsr_api');
        set_config('sis_api_key', 'test_api_key', 'local_pucsr_api');
        set_config('sis_timeout', 30, 'local_pucsr_api');
    }

    /**
     * Test SIS mapping creation and retrieval
     */
    public function test_sis_mapping() {
        global $DB;

        // Create SIS mapping for user
        $mapping_data = [
            'entity_type' => 'user',
            'moodle_id' => $this->user->id,
            'sis_id' => 'SIS_USER_123',
            'sis_code' => 'USER123',
            'active' => 1,
            'timecreated' => time(),
            'timemodified' => time()
        ];

        $mapping_id = $DB->insert_record('local_pucsr_api_sis_mapping', $mapping_data);
        $this->assertNotFalse($mapping_id);

        // Retrieve mapping
        $retrieved_mapping = $DB->get_record('local_pucsr_api_sis_mapping', ['id' => $mapping_id]);
        $this->assertNotFalse($retrieved_mapping);
        $this->assertEquals('user', $retrieved_mapping->entity_type);
        $this->assertEquals($this->user->id, $retrieved_mapping->moodle_id);
        $this->assertEquals('SIS_USER_123', $retrieved_mapping->sis_id);

        // Test unique constraints
        $duplicate_mapping = [
            'entity_type' => 'user',
            'moodle_id' => $this->user->id,
            'sis_id' => 'SIS_USER_456',
            'active' => 1,
            'timecreated' => time(),
            'timemodified' => time()
        ];

        // This should work (same moodle_id, different sis_id)
        $DB->insert_record('local_pucsr_api_sis_mapping', $duplicate_mapping);

        // But this should fail (same entity_type + sis_id)
        $this->expectException(\dml_write_exception::class);
        $DB->insert_record('local_pucsr_api_sis_mapping', [
            'entity_type' => 'user',
            'moodle_id' => 999,
            'sis_id' => 'SIS_USER_123', // Duplicate
            'active' => 1,
            'timecreated' => time(),
            'timemodified' => time()
        ]);
    }

    /**
     * Test sync logging
     */
    public function test_sync_logging() {
        global $DB;

        // Create sync log entry
        $log_data = [
            'sync_type' => 'grades',
            'courseid' => $this->course->id,
            'direction' => 'push',
            'records_processed' => 10,
            'records_success' => 8,
            'records_failed' => 2,
            'status' => 'partial',
            'error_message' => 'Some students not found in SIS',
            'sync_data' => json_encode(['test' => 'data']),
            'timecreated' => time(),
            'timemodified' => time()
        ];

        $log_id = $DB->insert_record('local_pucsr_api_sync_log', $log_data);
        $this->assertNotFalse($log_id);

        // Retrieve log
        $log_record = $DB->get_record('local_pucsr_api_sync_log', ['id' => $log_id]);
        $this->assertNotFalse($log_record);
        $this->assertEquals('grades', $log_record->sync_type);
        $this->assertEquals($this->course->id, $log_record->courseid);
        $this->assertEquals('push', $log_record->direction);
        $this->assertEquals(10, $log_record->records_processed);
        $this->assertEquals(8, $log_record->records_success);
        $this->assertEquals(2, $log_record->records_failed);
        $this->assertEquals('partial', $log_record->status);
    }

    /**
     * Test composite configuration storage
     */
    public function test_composite_config() {
        global $DB;

        // Create composite config
        $structure = [
            'name' => 'Test Structure',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Quiz 1', 'maxgrade' => 100]
                    ]
                ],
                [
                    'name' => 'Writing',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Essay 1', 'maxgrade' => 100]
                    ]
                ]
            ]
        ];

        $config_data = [
            'courseid' => $this->course->id,
            'main_category_id' => 123,
            'structure_name' => 'Test Structure',
            'config_data' => json_encode($structure),
            'active' => 1,
            'created_by' => $this->user->id,
            'timecreated' => time(),
            'timemodified' => time()
        ];

        $config_id = $DB->insert_record('local_pucsr_api_composite_config', $config_data);
        $this->assertNotFalse($config_id);

        // Retrieve and verify
        $config_record = $DB->get_record('local_pucsr_api_composite_config', ['id' => $config_id]);
        $this->assertNotFalse($config_record);
        $this->assertEquals($this->course->id, $config_record->courseid);
        $this->assertEquals('Test Structure', $config_record->structure_name);

        $decoded_structure = json_decode($config_record->config_data, true);
        $this->assertEquals($structure, $decoded_structure);
    }

    /**
     * Test configuration validation
     */
    public function test_configuration_validation() {
        // Test missing SIS URL
        set_config('sis_url', '', 'local_pucsr_api');

        $this->expectException(\moodle_exception::class);
        $this->expectExceptionMessage('error_missing_config');

        new \local_pucsr_api\api\sis_integration();
    }

    /**
     * Test SIS configuration check
     */
    public function test_sis_configuration_check() {
        // Valid configuration
        $this->assertTrue(get_config('local_pucsr_api', 'sis_enabled'));
        $this->assertEquals('https://sis.test.api', get_config('local_pucsr_api', 'sis_url'));
        $this->assertEquals('test_api_key', get_config('local_pucsr_api', 'sis_api_key'));
        $this->assertEquals(30, get_config('local_pucsr_api', 'sis_timeout'));

        // Test SIS integration creation with valid config
        $sis = new \local_pucsr_api\api\sis_integration();
        $this->assertInstanceOf(\local_pucsr_api\api\sis_integration::class, $sis);
    }

    /**
     * Test database table structure
     */
    public function test_database_tables() {
        global $DB;

        // Test sync log table
        $this->assertTrue($DB->get_manager()->table_exists('local_pucsr_api_sync_log'));

        // Test SIS mapping table
        $this->assertTrue($DB->get_manager()->table_exists('local_pucsr_api_sis_mapping'));

        // Test composite config table
        $this->assertTrue($DB->get_manager()->table_exists('local_pucsr_api_composite_config'));

        // Test field existence
        $sync_log_fields = $DB->get_columns('local_pucsr_api_sync_log');
        $this->assertArrayHasKey('sync_type', $sync_log_fields);
        $this->assertArrayHasKey('direction', $sync_log_fields);
        $this->assertArrayHasKey('records_processed', $sync_log_fields);
        $this->assertArrayHasKey('status', $sync_log_fields);

        $mapping_fields = $DB->get_columns('local_pucsr_api_sis_mapping');
        $this->assertArrayHasKey('entity_type', $mapping_fields);
        $this->assertArrayHasKey('moodle_id', $mapping_fields);
        $this->assertArrayHasKey('sis_id', $mapping_fields);
        $this->assertArrayHasKey('sis_code', $mapping_fields);

        $config_fields = $DB->get_columns('local_pucsr_api_composite_config');
        $this->assertArrayHasKey('structure_name', $config_fields);
        $this->assertArrayHasKey('config_data', $config_fields);
        $this->assertArrayHasKey('main_category_id', $config_fields);
    }

    /**
     * Test grade calculation scenarios
     */
    public function test_grade_calculation_scenarios() {
        global $DB;

        // Test scenario: Grammar 60%, Writing 40%
        $weights = ['grammar' => 0.6, 'writing' => 0.4];
        $grammar_grade = 85;
        $writing_grade = 90;

        $expected_composite = ($grammar_grade * $weights['grammar']) + ($writing_grade * $weights['writing']);
        $this->assertEquals(87, $expected_composite); // 85*0.6 + 90*0.4 = 51 + 36 = 87

        // Test scenario: Equal weights
        $weights = ['grammar' => 0.5, 'writing' => 0.5];
        $expected_composite = ($grammar_grade * $weights['grammar']) + ($writing_grade * $weights['writing']);
        $this->assertEquals(87.5, $expected_composite); // 85*0.5 + 90*0.5 = 42.5 + 45 = 87.5

        // Test scenario: Different grades
        $grammar_grade = 75;
        $writing_grade = 95;
        $expected_composite = ($grammar_grade * $weights['grammar']) + ($writing_grade * $weights['writing']);
        $this->assertEquals(85, $expected_composite); // 75*0.5 + 95*0.5 = 37.5 + 47.5 = 85
    }

    /**
     * Test data integrity constraints
     */
    public function test_data_integrity() {
        global $DB;

        // Test that courseid in composite_config references valid course
        $config_data = [
            'courseid' => 99999, // Non-existent course
            'main_category_id' => 123,
            'structure_name' => 'Test',
            'config_data' => '{}',
            'active' => 1,
            'created_by' => $this->user->id,
            'timecreated' => time(),
            'timemodified' => time()
        ];

        // This should fail due to foreign key constraint
        $this->expectException(\dml_write_exception::class);
        $DB->insert_record('local_pucsr_api_composite_config', $config_data);
    }

    /**
     * Test JSON data validation
     */
    public function test_json_data_validation() {
        $valid_structure = [
            'name' => 'Valid Structure',
            'components' => [
                [
                    'name' => 'Component 1',
                    'weight' => 1.0,
                    'subitems' => [
                        ['name' => 'Item 1', 'maxgrade' => 100]
                    ]
                ]
            ]
        ];

        $json_string = json_encode($valid_structure);
        $this->assertNotFalse($json_string);

        $decoded = json_decode($json_string, true);
        $this->assertEquals($valid_structure, $decoded);
        $this->assertEquals(JSON_ERROR_NONE, json_last_error());
    }
}