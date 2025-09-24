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
 * External API for composite grade management
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
use context_course;
use moodle_exception;

/**
 * External API for composite grade operations
 */
class composite_external extends external_api {

    /**
     * Parameters for create_composite_structure
     */
    public static function create_composite_structure_parameters() {
        return new external_function_parameters([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'structure' => new external_single_structure([
                'name' => new external_value(PARAM_TEXT, 'Main category name'),
                'components' => new external_multiple_structure(
                    new external_single_structure([
                        'name' => new external_value(PARAM_TEXT, 'Component name'),
                        'weight' => new external_value(PARAM_FLOAT, 'Weight (0-1)'),
                        'subitems' => new external_multiple_structure(
                            new external_single_structure([
                                'name' => new external_value(PARAM_TEXT, 'Item name'),
                                'maxgrade' => new external_value(PARAM_FLOAT, 'Max grade'),
                                'itemtype' => new external_value(PARAM_TEXT, 'Item type', VALUE_DEFAULT, 'manual')
                            ])
                        )
                    ])
                )
            ]),
            'ieap_level' => new external_value(PARAM_TEXT, 'IEAP level for auto-detection (optional)', VALUE_DEFAULT, null),
            'auto_detect' => new external_value(PARAM_BOOL, 'Auto-detect IEAP level from course name', VALUE_DEFAULT, false)
        ]);
    }

    /**
     * Create IEAP composite grade structure
     */
    public static function create_composite_structure($courseid, $structure, $ieap_level = null, $auto_detect = false) {
        global $DB, $CFG, $USER;
        require_once($CFG->libdir . '/gradelib.php');

        // Validate parameters
        $params = self::validate_parameters(
            self::create_composite_structure_parameters(),
            [
                'courseid' => $courseid,
                'structure' => $structure,
                'ieap_level' => $ieap_level,
                'auto_detect' => $auto_detect
            ]
        );

        // Auto-detect IEAP level if requested or if structure is minimal
        if ($auto_detect || $ieap_level) {
            $course = $DB->get_record('course', ['id' => $courseid], 'shortname, fullname', MUST_EXIST);

            if ($auto_detect) {
                $detected_level = \local_pucsr_api\api\ieap_templates::detect_ieap_level($course->shortname . ' ' . $course->fullname);
                if ($detected_level) {
                    $ieap_level = $detected_level;
                }
            }

            if ($ieap_level) {
                // Override structure with IEAP template
                try {
                    $structure = \local_pucsr_api\api\ieap_templates::get_template($ieap_level);
                    mtrace("Using IEAP template: {$ieap_level}");
                } catch (\Exception $e) {
                    throw new moodle_exception('invalid_ieap_template', 'local_pucsr_api', '', $ieap_level);
                }
            }
        }

        // Validate context
        $context = context_course::instance($courseid);
        self::validate_context($context);
        require_capability('moodle/grade:manage', $context);

        // Check if composite structure already exists
        if ($DB->record_exists('local_pucsr_api_composite_config', ['courseid' => $courseid, 'active' => 1])) {
            throw new moodle_exception('structure_exists', 'local_pucsr_api');
        }

        $transaction = $DB->start_delegated_transaction();

        try {
            // Create main category
            $main_category = \grade_category::fetch_course_category($courseid);

            $composite_cat = new \grade_category([
                'courseid' => $courseid,
                'fullname' => $structure['name'],
                'parent' => $main_category->id,
                'aggregation' => GRADE_AGGREGATE_WEIGHTED_MEAN2
            ], false);
            $composite_cat->insert();

            $results = ['main_category_id' => $composite_cat->id, 'components' => []];

            // Validate weights sum to 1.0
            $total_weight = 0;
            foreach ($structure['components'] as $component) {
                $total_weight += $component['weight'];
            }
            if (abs($total_weight - 1.0) > 0.001) {
                throw new moodle_exception('invalid_weights', 'local_pucsr_api', '', $total_weight);
            }

            // Create component categories
            foreach ($structure['components'] as $component) {
                $comp_cat = new \grade_category([
                    'courseid' => $courseid,
                    'parent' => $composite_cat->id,
                    'fullname' => $component['name'],
                    'aggregation' => GRADE_AGGREGATE_WEIGHTED_MEAN2,
                    'aggregationcoef2' => $component['weight']
                ], false);
                $comp_cat->insert();

                $items = [];
                // Create grade items
                foreach ($component['subitems'] as $item) {
                    $grade_item = new \grade_item([
                        'courseid' => $courseid,
                        'categoryid' => $comp_cat->id,
                        'itemname' => $item['name'],
                        'itemtype' => $item['itemtype'],
                        'grademax' => $item['maxgrade'],
                        'grademin' => 0,
                        'gradetype' => GRADE_TYPE_VALUE
                    ], false);
                    $grade_item->insert();

                    $items[] = [
                        'id' => $grade_item->id,
                        'name' => $item['name'],
                        'maxgrade' => $item['maxgrade']
                    ];
                }

                $results['components'][] = [
                    'category_id' => $comp_cat->id,
                    'name' => $component['name'],
                    'weight' => $component['weight'],
                    'items' => $items
                ];
            }

            // Save configuration
            $config_record = [
                'courseid' => $courseid,
                'main_category_id' => $composite_cat->id,
                'structure_name' => $structure['name'],
                'config_data' => json_encode($structure),
                'active' => 1,
                'created_by' => $USER->id,
                'timecreated' => time(),
                'timemodified' => time()
            ];
            $DB->insert_record('local_pucsr_api_composite_config', $config_record);

            $transaction->allow_commit();

            // Trigger event for logging
            $event = \local_pucsr_api\event\composite_structure_created::create([
                'context' => $context,
                'objectid' => $composite_cat->id,
                'courseid' => $courseid,
                'other' => ['structure_name' => $structure['name']]
            ]);
            $event->trigger();

            return $results;

        } catch (\Exception $e) {
            $transaction->rollback($e);
            throw new moodle_exception('error_creating_structure', 'local_pucsr_api', '', $e->getMessage());
        }
    }

    /**
     * Return description for create_composite_structure
     */
    public static function create_composite_structure_returns() {
        return new external_single_structure([
            'main_category_id' => new external_value(PARAM_INT, 'Main category ID'),
            'components' => new external_multiple_structure(
                new external_single_structure([
                    'category_id' => new external_value(PARAM_INT, 'Category ID'),
                    'name' => new external_value(PARAM_TEXT, 'Component name'),
                    'weight' => new external_value(PARAM_FLOAT, 'Component weight'),
                    'items' => new external_multiple_structure(
                        new external_single_structure([
                            'id' => new external_value(PARAM_INT, 'Item ID'),
                            'name' => new external_value(PARAM_TEXT, 'Item name'),
                            'maxgrade' => new external_value(PARAM_FLOAT, 'Maximum grade')
                        ])
                    )
                ])
            )
        ]);
    }

    /**
     * Parameters for get_composite_grades
     */
    public static function get_composite_grades_parameters() {
        return new external_function_parameters([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'userid' => new external_value(PARAM_INT, 'User ID (optional, returns all if not specified)', VALUE_DEFAULT, null),
            'include_breakdown' => new external_value(PARAM_BOOL, 'Include component breakdown', VALUE_DEFAULT, true)
        ]);
    }

    /**
     * Get composite grades for students
     */
    public static function get_composite_grades($courseid, $userid = null, $include_breakdown = true) {
        global $DB, $CFG;
        require_once($CFG->libdir . '/gradelib.php');

        // Validate parameters
        $params = self::validate_parameters(
            self::get_composite_grades_parameters(),
            ['courseid' => $courseid, 'userid' => $userid, 'include_breakdown' => $include_breakdown]
        );

        // Validate context
        $context = context_course::instance($courseid);
        self::validate_context($context);
        require_capability('moodle/grade:view', $context);

        // Get composite configuration
        $config = $DB->get_record('local_pucsr_api_composite_config',
            ['courseid' => $courseid, 'active' => 1]);

        if (!$config) {
            throw new moodle_exception('no_composite_structure', 'local_pucsr_api');
        }

        // Get grade tree for course
        $gtree = new \grade_tree($courseid, false, false);

        $results = [];

        // Get enrolled users
        $enrolled_users = get_enrolled_users($context, 'moodle/grade:view');

        if ($userid) {
            if (!isset($enrolled_users[$userid])) {
                throw new moodle_exception('user_not_enrolled', 'local_pucsr_api');
            }
            $enrolled_users = [$userid => $enrolled_users[$userid]];
        }

        foreach ($enrolled_users as $user) {
            $user_grades = [
                'userid' => $user->id,
                'firstname' => $user->firstname,
                'lastname' => $user->lastname,
                'email' => $user->email
            ];

            if ($include_breakdown) {
                $user_grades['components'] = [];
                $user_grades['composite_grade'] = null;

                // Get grades from main composite category
                $main_cat = $DB->get_record('grade_categories', ['id' => $config->main_category_id]);
                if ($main_cat) {
                    $grade_grade = \grade_grade::fetch(['itemid' => $main_cat->id, 'userid' => $user->id]);
                    if ($grade_grade && !empty($grade_grade->finalgrade)) {
                        $user_grades['composite_grade'] = floatval($grade_grade->finalgrade);
                    }
                }

                // Get component grades
                $structure = json_decode($config->config_data, true);
                foreach ($structure['components'] as $component_config) {
                    $component_data = [
                        'name' => $component_config['name'],
                        'weight' => $component_config['weight'],
                        'items' => [],
                        'component_grade' => null
                    ];

                    // Find component category
                    $comp_cat = $DB->get_record('grade_categories', [
                        'parent' => $config->main_category_id,
                        'fullname' => $component_config['name']
                    ]);

                    if ($comp_cat) {
                        // Get component grade
                        $comp_grade = \grade_grade::fetch(['itemid' => $comp_cat->id, 'userid' => $user->id]);
                        if ($comp_grade && !empty($comp_grade->finalgrade)) {
                            $component_data['component_grade'] = floatval($comp_grade->finalgrade);
                        }

                        // Get individual item grades
                        foreach ($component_config['subitems'] as $subitem_config) {
                            $grade_item = $DB->get_record('grade_items', [
                                'categoryid' => $comp_cat->id,
                                'itemname' => $subitem_config['name']
                            ]);

                            if ($grade_item) {
                                $item_grade = \grade_grade::fetch(['itemid' => $grade_item->id, 'userid' => $user->id]);
                                $item_data = [
                                    'name' => $subitem_config['name'],
                                    'maxgrade' => floatval($grade_item->grademax),
                                    'grade' => null,
                                    'percentage' => null
                                ];

                                if ($item_grade && !empty($item_grade->finalgrade)) {
                                    $item_data['grade'] = floatval($item_grade->finalgrade);
                                    $item_data['percentage'] = ($item_data['grade'] / $item_data['maxgrade']) * 100;
                                }

                                $component_data['items'][] = $item_data;
                            }
                        }
                    }

                    $user_grades['components'][] = $component_data;
                }
            } else {
                // Just get the composite grade
                $main_cat = $DB->get_record('grade_categories', ['id' => $config->main_category_id]);
                if ($main_cat) {
                    $grade_grade = \grade_grade::fetch(['itemid' => $main_cat->id, 'userid' => $user->id]);
                    if ($grade_grade && !empty($grade_grade->finalgrade)) {
                        $user_grades['composite_grade'] = floatval($grade_grade->finalgrade);
                    } else {
                        $user_grades['composite_grade'] = null;
                    }
                }
            }

            $results[] = $user_grades;
        }

        return [
            'courseid' => $courseid,
            'structure_name' => $config->structure_name,
            'grades' => $results
        ];
    }

    /**
     * Return description for get_composite_grades
     */
    public static function get_composite_grades_returns() {
        return new external_single_structure([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'structure_name' => new external_value(PARAM_TEXT, 'Structure name'),
            'grades' => new external_multiple_structure(
                new external_single_structure([
                    'userid' => new external_value(PARAM_INT, 'User ID'),
                    'firstname' => new external_value(PARAM_TEXT, 'First name'),
                    'lastname' => new external_value(PARAM_TEXT, 'Last name'),
                    'email' => new external_value(PARAM_EMAIL, 'Email'),
                    'composite_grade' => new external_value(PARAM_FLOAT, 'Composite grade', VALUE_OPTIONAL),
                    'components' => new external_multiple_structure(
                        new external_single_structure([
                            'name' => new external_value(PARAM_TEXT, 'Component name'),
                            'weight' => new external_value(PARAM_FLOAT, 'Component weight'),
                            'component_grade' => new external_value(PARAM_FLOAT, 'Component grade', VALUE_OPTIONAL),
                            'items' => new external_multiple_structure(
                                new external_single_structure([
                                    'name' => new external_value(PARAM_TEXT, 'Item name'),
                                    'maxgrade' => new external_value(PARAM_FLOAT, 'Maximum grade'),
                                    'grade' => new external_value(PARAM_FLOAT, 'Current grade', VALUE_OPTIONAL),
                                    'percentage' => new external_value(PARAM_FLOAT, 'Percentage', VALUE_OPTIONAL)
                                ])
                            )
                        ]), VALUE_OPTIONAL
                    )
                ])
            )
        ]);
    }

    /**
     * Parameters for update_composite_grades
     */
    public static function update_composite_grades_parameters() {
        return new external_function_parameters([
            'updates' => new external_multiple_structure(
                new external_single_structure([
                    'courseid' => new external_value(PARAM_INT, 'Course ID'),
                    'userid' => new external_value(PARAM_INT, 'User ID'),
                    'itemid' => new external_value(PARAM_INT, 'Grade item ID'),
                    'grade' => new external_value(PARAM_FLOAT, 'New grade value')
                ])
            )
        ]);
    }

    /**
     * Update grades in composite structure
     */
    public static function update_composite_grades($updates) {
        global $DB, $CFG;
        require_once($CFG->libdir . '/gradelib.php');

        // Validate parameters
        $params = self::validate_parameters(
            self::update_composite_grades_parameters(),
            ['updates' => $updates]
        );

        $results = [];
        $transaction = $DB->start_delegated_transaction();

        try {
            foreach ($updates as $update) {
                // Validate context
                $context = context_course::instance($update['courseid']);
                self::validate_context($context);
                require_capability('moodle/grade:edit', $context);

                // Get grade item
                $grade_item = $DB->get_record('grade_items', ['id' => $update['itemid']]);
                if (!$grade_item || $grade_item->courseid != $update['courseid']) {
                    throw new moodle_exception('invalid_grade_item', 'local_pucsr_api');
                }

                // Validate grade value
                if ($update['grade'] < $grade_item->grademin || $update['grade'] > $grade_item->grademax) {
                    throw new moodle_exception('invalid_grade_value', 'local_pucsr_api', '',
                        "{$update['grade']} not in range {$grade_item->grademin}-{$grade_item->grademax}");
                }

                // Get or create grade_grade record
                $grade_grade = \grade_grade::fetch(['itemid' => $update['itemid'], 'userid' => $update['userid']]);
                if (!$grade_grade) {
                    $grade_grade = new \grade_grade(['itemid' => $update['itemid'], 'userid' => $update['userid']]);
                }

                $grade_grade->finalgrade = $update['grade'];
                $grade_grade->timemodified = time();

                if ($grade_grade->id) {
                    $grade_grade->update();
                } else {
                    $grade_grade->insert();
                }

                $results[] = [
                    'courseid' => $update['courseid'],
                    'userid' => $update['userid'],
                    'itemid' => $update['itemid'],
                    'grade' => $update['grade'],
                    'success' => true
                ];
            }

            $transaction->allow_commit();

        } catch (\Exception $e) {
            $transaction->rollback($e);
            throw $e;
        }

        return ['updates' => $results];
    }

    /**
     * Return description for update_composite_grades
     */
    public static function update_composite_grades_returns() {
        return new external_single_structure([
            'updates' => new external_multiple_structure(
                new external_single_structure([
                    'courseid' => new external_value(PARAM_INT, 'Course ID'),
                    'userid' => new external_value(PARAM_INT, 'User ID'),
                    'itemid' => new external_value(PARAM_INT, 'Grade item ID'),
                    'grade' => new external_value(PARAM_FLOAT, 'Updated grade'),
                    'success' => new external_value(PARAM_BOOL, 'Update success')
                ])
            )
        ]);
    }

    /**
     * Parameters for get_ieap_templates
     */
    public static function get_ieap_templates_parameters() {
        return new external_function_parameters([
            'level' => new external_value(PARAM_TEXT, 'Specific IEAP level (optional)', VALUE_DEFAULT, null)
        ]);
    }

    /**
     * Get available IEAP templates
     */
    public static function get_ieap_templates($level = null) {
        // Validate parameters
        $params = self::validate_parameters(
            self::get_ieap_templates_parameters(),
            ['level' => $level]
        );

        // Validate context
        $context = \context_system::instance();
        self::validate_context($context);
        require_capability('local/pucsr_api:view_composite', $context);

        if ($level) {
            try {
                $template = \local_pucsr_api\api\ieap_templates::get_template($level);
                return [
                    'templates' => [$level => $template],
                    'available_levels' => \local_pucsr_api\api\ieap_templates::get_available_levels()
                ];
            } catch (\Exception $e) {
                throw new moodle_exception('invalid_ieap_level', 'local_pucsr_api', '', $level);
            }
        } else {
            return [
                'templates' => \local_pucsr_api\api\ieap_templates::get_all_templates(),
                'available_levels' => \local_pucsr_api\api\ieap_templates::get_available_levels()
            ];
        }
    }

    /**
     * Return description for get_ieap_templates
     */
    public static function get_ieap_templates_returns() {
        return new external_single_structure([
            'templates' => new external_single_structure([
                'ieap1' => new external_single_structure([
                    'name' => new external_value(PARAM_TEXT, 'Template name'),
                    'description' => new external_value(PARAM_TEXT, 'Template description'),
                    'level' => new external_value(PARAM_TEXT, 'Difficulty level'),
                    'components' => new external_multiple_structure(
                        new external_single_structure([
                            'name' => new external_value(PARAM_TEXT, 'Component name'),
                            'weight' => new external_value(PARAM_FLOAT, 'Component weight'),
                            'subitems' => new external_multiple_structure(
                                new external_single_structure([
                                    'name' => new external_value(PARAM_TEXT, 'Item name'),
                                    'maxgrade' => new external_value(PARAM_FLOAT, 'Maximum grade'),
                                    'itemtype' => new external_value(PARAM_TEXT, 'Item type')
                                ])
                            )
                        ])
                    )
                ], VALUE_OPTIONAL)
            ], VALUE_OPTIONAL),
            'available_levels' => new external_multiple_structure(
                new external_value(PARAM_TEXT, 'Available IEAP level')
            )
        ]);
    }

    /**
     * Parameters for detect_ieap_level
     */
    public static function detect_ieap_level_parameters() {
        return new external_function_parameters([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'course_name' => new external_value(PARAM_TEXT, 'Course name to analyze (optional)', VALUE_DEFAULT, null)
        ]);
    }

    /**
     * Detect IEAP level from course information
     */
    public static function detect_ieap_level($courseid, $course_name = null) {
        global $DB;

        // Validate parameters
        $params = self::validate_parameters(
            self::detect_ieap_level_parameters(),
            ['courseid' => $courseid, 'course_name' => $course_name]
        );

        // Validate context
        $context = \context_course::instance($courseid);
        self::validate_context($context);
        require_capability('moodle/course:view', $context);

        if (!$course_name) {
            $course = $DB->get_record('course', ['id' => $courseid], 'shortname, fullname', MUST_EXIST);
            $course_name = $course->shortname . ' ' . $course->fullname;
        }

        $detected_level = \local_pucsr_api\api\ieap_templates::detect_ieap_level($course_name);

        $result = [
            'courseid' => $courseid,
            'course_name' => $course_name,
            'detected_level' => $detected_level,
            'confidence' => $detected_level ? 'high' : 'none'
        ];

        if ($detected_level) {
            $template = \local_pucsr_api\api\ieap_templates::get_template($detected_level);
            $result['template_preview'] = [
                'name' => $template['name'],
                'description' => $template['description'],
                'component_count' => count($template['components']),
                'components' => array_map(function($comp) {
                    return [
                        'name' => $comp['name'],
                        'weight' => $comp['weight'],
                        'item_count' => count($comp['subitems'])
                    ];
                }, $template['components'])
            ];
        }

        return $result;
    }

    /**
     * Return description for detect_ieap_level
     */
    public static function detect_ieap_level_returns() {
        return new external_single_structure([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'course_name' => new external_value(PARAM_TEXT, 'Course name analyzed'),
            'detected_level' => new external_value(PARAM_TEXT, 'Detected IEAP level', VALUE_OPTIONAL),
            'confidence' => new external_value(PARAM_TEXT, 'Detection confidence'),
            'template_preview' => new external_single_structure([
                'name' => new external_value(PARAM_TEXT, 'Template name'),
                'description' => new external_value(PARAM_TEXT, 'Template description'),
                'component_count' => new external_value(PARAM_INT, 'Number of components'),
                'components' => new external_multiple_structure(
                    new external_single_structure([
                        'name' => new external_value(PARAM_TEXT, 'Component name'),
                        'weight' => new external_value(PARAM_FLOAT, 'Component weight'),
                        'item_count' => new external_value(PARAM_INT, 'Number of items')
                    ])
                )
            ], VALUE_OPTIONAL)
        ]);
    }

    /**
     * Parameters for create_ieap_structure
     */
    public static function create_ieap_structure_parameters() {
        return new external_function_parameters([
            'courseid' => new external_value(PARAM_INT, 'Course ID'),
            'ieap_level' => new external_value(PARAM_TEXT, 'IEAP level (ieap1-ieap6)'),
            'customizations' => new external_single_structure([
                'grammar_weight' => new external_value(PARAM_FLOAT, 'Grammar component weight', VALUE_DEFAULT, null),
                'writing_weight' => new external_value(PARAM_FLOAT, 'Writing component weight', VALUE_DEFAULT, null),
                'speaking_weight' => new external_value(PARAM_FLOAT, 'Speaking component weight', VALUE_DEFAULT, null),
                'listening_weight' => new external_value(PARAM_FLOAT, 'Listening component weight', VALUE_DEFAULT, null),
                'reading_weight' => new external_value(PARAM_FLOAT, 'Reading component weight', VALUE_DEFAULT, null)
            ], VALUE_DEFAULT, [])
        ]);
    }

    /**
     * Create IEAP structure using template
     */
    public static function create_ieap_structure($courseid, $ieap_level, $customizations = []) {
        // Validate parameters
        $params = self::validate_parameters(
            self::create_ieap_structure_parameters(),
            ['courseid' => $courseid, 'ieap_level' => $ieap_level, 'customizations' => $customizations]
        );

        // Validate context
        $context = \context_course::instance($courseid);
        self::validate_context($context);
        require_capability('moodle/grade:manage', $context);

        try {
            // Get template with customizations
            $structure = \local_pucsr_api\api\ieap_templates::get_customized_template($ieap_level, $customizations);

            // Create the structure using existing method
            return self::create_composite_structure($courseid, $structure);

        } catch (\Exception $e) {
            throw new moodle_exception('error_creating_ieap_structure', 'local_pucsr_api', '', $e->getMessage());
        }
    }

    /**
     * Return description for create_ieap_structure
     */
    public static function create_ieap_structure_returns() {
        return self::create_composite_structure_returns();
    }
}