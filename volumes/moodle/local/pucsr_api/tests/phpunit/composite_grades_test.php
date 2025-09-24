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
 * Unit tests for composite grades functionality
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_pucsr_api;

use advanced_testcase;
use context_course;

/**
 * Test composite grades API functionality
 */
class composite_grades_test extends advanced_testcase {

    /** @var object Test course */
    private $course;

    /** @var object Test user (student) */
    private $student;

    /** @var object Test user (teacher) */
    private $teacher;

    /**
     * Set up test environment
     */
    protected function setUp(): void {
        $this->resetAfterTest();

        // Create test course
        $this->course = $this->getDataGenerator()->create_course([
            'shortname' => 'IEAP4TEST',
            'fullname' => 'IEAP-4 Test Course'
        ]);

        // Create test users
        $this->student = $this->getDataGenerator()->create_user([
            'firstname' => 'Test',
            'lastname' => 'Student',
            'email' => 'student@test.com'
        ]);

        $this->teacher = $this->getDataGenerator()->create_user([
            'firstname' => 'Test',
            'lastname' => 'Teacher',
            'email' => 'teacher@test.com'
        ]);

        // Enroll users
        $this->getDataGenerator()->enrol_user($this->student->id, $this->course->id, 'student');
        $this->getDataGenerator()->enrol_user($this->teacher->id, $this->course->id, 'editingteacher');
    }

    /**
     * Test creating IEAP-4 composite structure
     */
    public function test_create_ieap4_structure() {
        global $DB;

        $this->setUser($this->teacher);

        // Define IEAP-4 structure
        $structure = [
            'name' => 'IEAP-4',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Quiz 2', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Writing',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Essay 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Essay 2', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        // Create structure using external API
        $api = new \local_pucsr_api\external\composite_external();
        $result = $api::create_composite_structure($this->course->id, $structure);

        // Verify result structure
        $this->assertNotEmpty($result['main_category_id']);
        $this->assertCount(2, $result['components']);

        // Verify Grammar component
        $grammar_component = null;
        $writing_component = null;
        foreach ($result['components'] as $component) {
            if ($component['name'] === 'Grammar') {
                $grammar_component = $component;
            } elseif ($component['name'] === 'Writing') {
                $writing_component = $component;
            }
        }

        $this->assertNotNull($grammar_component);
        $this->assertNotNull($writing_component);
        $this->assertEquals(0.5, $grammar_component['weight']);
        $this->assertEquals(0.5, $writing_component['weight']);
        $this->assertCount(2, $grammar_component['items']);
        $this->assertCount(2, $writing_component['items']);

        // Verify database records
        $config_record = $DB->get_record('local_pucsr_api_composite_config', [
            'courseid' => $this->course->id,
            'active' => 1
        ]);
        $this->assertNotFalse($config_record);
        $this->assertEquals('IEAP-4', $config_record->structure_name);

        // Verify grade categories were created
        $main_category = $DB->get_record('grade_categories', ['id' => $result['main_category_id']]);
        $this->assertNotFalse($main_category);
        $this->assertEquals('IEAP-4', $main_category->fullname);
    }

    /**
     * Test invalid weight structure
     */
    public function test_invalid_weights() {
        $this->setUser($this->teacher);

        $structure = [
            'name' => 'Invalid Structure',
            'components' => [
                [
                    'name' => 'Component 1',
                    'weight' => 0.3, // Total will be 0.8, not 1.0
                    'subitems' => [
                        ['name' => 'Item 1', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Component 2',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Item 2', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        $this->expectException(\moodle_exception::class);
        $this->expectExceptionMessage('invalid_weights');

        $api = new \local_pucsr_api\external\composite_external();
        $api::create_composite_structure($this->course->id, $structure);
    }

    /**
     * Test duplicate structure creation
     */
    public function test_duplicate_structure() {
        global $DB;

        $this->setUser($this->teacher);

        // Create first structure
        $structure = [
            'name' => 'Test Structure',
            'components' => [
                [
                    'name' => 'Component 1',
                    'weight' => 1.0,
                    'subitems' => [
                        ['name' => 'Item 1', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        $api = new \local_pucsr_api\external\composite_external();
        $api::create_composite_structure($this->course->id, $structure);

        // Try to create second structure (should fail)
        $this->expectException(\moodle_exception::class);
        $this->expectExceptionMessage('structure_exists');

        $api::create_composite_structure($this->course->id, $structure);
    }

    /**
     * Test getting composite grades
     */
    public function test_get_composite_grades() {
        global $DB, $CFG;
        require_once($CFG->libdir . '/gradelib.php');

        $this->setUser($this->teacher);

        // Create structure first
        $structure = [
            'name' => 'Test Grades',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 0.6,
                    'subitems' => [
                        ['name' => 'Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Writing',
                    'weight' => 0.4,
                    'subitems' => [
                        ['name' => 'Essay 1', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        $api = new \local_pucsr_api\external\composite_external();
        $create_result = $api::create_composite_structure($this->course->id, $structure);

        // Add some test grades
        $grammar_item_id = $create_result['components'][0]['items'][0]['id'];
        $writing_item_id = $create_result['components'][1]['items'][0]['id'];

        // Create grade records
        $grammar_grade = new \grade_grade([
            'itemid' => $grammar_item_id,
            'userid' => $this->student->id,
            'finalgrade' => 85,
            'timecreated' => time(),
            'timemodified' => time()
        ]);
        $grammar_grade->insert();

        $writing_grade = new \grade_grade([
            'itemid' => $writing_item_id,
            'userid' => $this->student->id,
            'finalgrade' => 90,
            'timecreated' => time(),
            'timemodified' => time()
        ]);
        $writing_grade->insert();

        // Recalculate grades
        grade_regrade_final_grades($this->course->id);

        // Get composite grades
        $result = $api::get_composite_grades($this->course->id, null, true);

        $this->assertEquals($this->course->id, $result['courseid']);
        $this->assertEquals('Test Grades', $result['structure_name']);
        $this->assertCount(1, $result['grades']); // One student

        $student_grade = $result['grades'][0];
        $this->assertEquals($this->student->id, $student_grade['userid']);
        $this->assertCount(2, $student_grade['components']);

        // Check component grades
        $grammar_component = null;
        $writing_component = null;
        foreach ($student_grade['components'] as $component) {
            if ($component['name'] === 'Grammar') {
                $grammar_component = $component;
            } elseif ($component['name'] === 'Writing') {
                $writing_component = $component;
            }
        }

        $this->assertNotNull($grammar_component);
        $this->assertNotNull($writing_component);
        $this->assertEquals(0.6, $grammar_component['weight']);
        $this->assertEquals(0.4, $writing_component['weight']);
        $this->assertEquals(85, $grammar_component['items'][0]['grade']);
        $this->assertEquals(90, $writing_component['items'][0]['grade']);
    }

    /**
     * Test updating composite grades
     */
    public function test_update_composite_grades() {
        global $DB;

        $this->setUser($this->teacher);

        // Create structure
        $structure = [
            'name' => 'Update Test',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 1.0,
                    'subitems' => [
                        ['name' => 'Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        $api = new \local_pucsr_api\external\composite_external();
        $create_result = $api::create_composite_structure($this->course->id, $structure);

        $item_id = $create_result['components'][0]['items'][0]['id'];

        // Update grade
        $updates = [
            [
                'courseid' => $this->course->id,
                'userid' => $this->student->id,
                'itemid' => $item_id,
                'grade' => 85.5
            ]
        ];

        $update_result = $api::update_composite_grades($updates);

        $this->assertCount(1, $update_result['updates']);
        $this->assertTrue($update_result['updates'][0]['success']);
        $this->assertEquals(85.5, $update_result['updates'][0]['grade']);

        // Verify grade was saved
        $grade_record = $DB->get_record('grade_grades', [
            'itemid' => $item_id,
            'userid' => $this->student->id
        ]);
        $this->assertNotFalse($grade_record);
        $this->assertEquals(85.5, $grade_record->finalgrade);
    }

    /**
     * Test invalid grade value
     */
    public function test_invalid_grade_value() {
        $this->setUser($this->teacher);

        // Create structure
        $structure = [
            'name' => 'Invalid Grade Test',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 1.0,
                    'subitems' => [
                        ['name' => 'Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        $api = new \local_pucsr_api\external\composite_external();
        $create_result = $api::create_composite_structure($this->course->id, $structure);

        $item_id = $create_result['components'][0]['items'][0]['id'];

        // Try to set grade above maximum
        $updates = [
            [
                'courseid' => $this->course->id,
                'userid' => $this->student->id,
                'itemid' => $item_id,
                'grade' => 150 // Max is 100
            ]
        ];

        $this->expectException(\moodle_exception::class);
        $this->expectExceptionMessage('invalid_grade_value');

        $api::update_composite_grades($updates);
    }

    /**
     * Test permissions
     */
    public function test_permissions() {
        // Test as student (should not be able to create structure)
        $this->setUser($this->student);

        $structure = [
            'name' => 'Permission Test',
            'components' => [
                [
                    'name' => 'Component',
                    'weight' => 1.0,
                    'subitems' => [
                        ['name' => 'Item', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];

        $this->expectException(\required_capability_exception::class);

        $api = new \local_pucsr_api\external\composite_external();
        $api::create_composite_structure($this->course->id, $structure);
    }
}