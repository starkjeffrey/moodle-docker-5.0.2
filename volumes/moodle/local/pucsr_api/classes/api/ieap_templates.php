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
 * IEAP Course Templates and Configuration
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_pucsr_api\api;

use moodle_exception;

/**
 * IEAP course template management class
 */
class ieap_templates {

    /**
     * Get all available IEAP course templates
     *
     * @return array Array of IEAP templates
     */
    public static function get_all_templates() {
        return [
            'ieap1' => self::get_ieap1_template(),
            'ieap2' => self::get_ieap2_template(),
            'ieap3' => self::get_ieap3_template(),
            'ieap4' => self::get_ieap4_template(),
            'ieap5' => self::get_ieap5_template(),
            'ieap6' => self::get_ieap6_template(),
        ];
    }

    /**
     * Get template for specific IEAP level
     *
     * @param string $level IEAP level (ieap1-ieap6)
     * @return array Template structure
     * @throws moodle_exception
     */
    public static function get_template($level) {
        $level = strtolower($level);

        switch ($level) {
            case 'ieap1':
                return self::get_ieap1_template();
            case 'ieap2':
                return self::get_ieap2_template();
            case 'ieap3':
                return self::get_ieap3_template();
            case 'ieap4':
                return self::get_ieap4_template();
            case 'ieap5':
                return self::get_ieap5_template();
            case 'ieap6':
                return self::get_ieap6_template();
            default:
                throw new moodle_exception('invalid_ieap_level', 'local_pucsr_api', '', $level);
        }
    }

    /**
     * Detect IEAP level from course name or shortname
     *
     * @param string $course_name Course full name or shortname
     * @return string|null IEAP level or null if not detected
     */
    public static function detect_ieap_level($course_name) {
        $course_name = strtolower($course_name);

        // Pattern matching for IEAP levels
        $patterns = [
            'ieap1' => ['/ieap\s*1/', '/ieap-1/', '/intensive.*english.*1/', '/english.*level.*1/'],
            'ieap2' => ['/ieap\s*2/', '/ieap-2/', '/intensive.*english.*2/', '/english.*level.*2/'],
            'ieap3' => ['/ieap\s*3/', '/ieap-3/', '/intensive.*english.*3/', '/english.*level.*3/'],
            'ieap4' => ['/ieap\s*4/', '/ieap-4/', '/intensive.*english.*4/', '/english.*level.*4/'],
            'ieap5' => ['/ieap\s*5/', '/ieap-5/', '/intensive.*english.*5/', '/english.*level.*5/'],
            'ieap6' => ['/ieap\s*6/', '/ieap-6/', '/intensive.*english.*6/', '/english.*level.*6/'],
        ];

        foreach ($patterns as $level => $level_patterns) {
            foreach ($level_patterns as $pattern) {
                if (preg_match($pattern, $course_name)) {
                    return $level;
                }
            }
        }

        return null;
    }

    /**
     * Get customized template based on course requirements
     *
     * @param string $level IEAP level
     * @param array $options Customization options
     * @return array Customized template
     */
    public static function get_customized_template($level, $options = []) {
        $template = self::get_template($level);

        // Apply customizations
        if (isset($options['grammar_weight'])) {
            $template = self::adjust_component_weight($template, 'Grammar', $options['grammar_weight']);
        }

        if (isset($options['writing_weight'])) {
            $template = self::adjust_component_weight($template, 'Writing', $options['writing_weight']);
        }

        if (isset($options['speaking_weight']) && self::has_component($template, 'Speaking')) {
            $template = self::adjust_component_weight($template, 'Speaking', $options['speaking_weight']);
        }

        if (isset($options['listening_weight']) && self::has_component($template, 'Listening')) {
            $template = self::adjust_component_weight($template, 'Listening', $options['listening_weight']);
        }

        if (isset($options['reading_weight']) && self::has_component($template, 'Reading')) {
            $template = self::adjust_component_weight($template, 'Reading', $options['reading_weight']);
        }

        // Normalize weights to ensure they sum to 1.0
        $template = self::normalize_weights($template);

        return $template;
    }

    /**
     * IEAP-1 Template: Basic English Foundation
     */
    private static function get_ieap1_template() {
        return [
            'name' => 'IEAP-1',
            'description' => 'Basic English Foundation Course',
            'level' => 'Beginner',
            'components' => [
                [
                    'name' => 'Grammar & Vocabulary',
                    'weight' => 0.4,
                    'subitems' => [
                        ['name' => 'Basic Grammar Quiz 1', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Basic Grammar Quiz 2', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Vocabulary Test 1', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Vocabulary Test 2', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Final Exam', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Speaking & Listening',
                    'weight' => 0.35,
                    'subitems' => [
                        ['name' => 'Pronunciation Practice', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Basic Conversation', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Listening Comprehension 1', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Listening Comprehension 2', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Speaking Assessment', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Basic Writing',
                    'weight' => 0.25,
                    'subitems' => [
                        ['name' => 'Sentence Writing', 'maxgrade' => 50, 'itemtype' => 'manual'],
                        ['name' => 'Paragraph Writing 1', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Paragraph Writing 2', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Basic Essay', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];
    }

    /**
     * IEAP-2 Template: Elementary English
     */
    private static function get_ieap2_template() {
        return [
            'name' => 'IEAP-2',
            'description' => 'Elementary English Course',
            'level' => 'Elementary',
            'components' => [
                [
                    'name' => 'Grammar & Vocabulary',
                    'weight' => 0.35,
                    'subitems' => [
                        ['name' => 'Grammar Quiz 1', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Quiz 2', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Vocabulary Test 1', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Vocabulary Test 2', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Midterm', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Final', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Speaking & Listening',
                    'weight' => 0.35,
                    'subitems' => [
                        ['name' => 'Pronunciation Assessment', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Dialogue Practice', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Listening Test 1', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Listening Test 2', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Oral Presentation', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Writing',
                    'weight' => 0.3,
                    'subitems' => [
                        ['name' => 'Paragraph Writing 1', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Paragraph Writing 2', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Short Essay 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Short Essay 2', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];
    }

    /**
     * IEAP-3 Template: Pre-Intermediate English
     */
    private static function get_ieap3_template() {
        return [
            'name' => 'IEAP-3',
            'description' => 'Pre-Intermediate English Course',
            'level' => 'Pre-Intermediate',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 0.3,
                    'subitems' => [
                        ['name' => 'Grammar Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Quiz 2', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Midterm', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Final', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Writing',
                    'weight' => 0.35,
                    'subitems' => [
                        ['name' => 'Essay 1: Descriptive', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Essay 2: Narrative', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Research Project', 'maxgrade' => 150, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Speaking',
                    'weight' => 0.2,
                    'subitems' => [
                        ['name' => 'Individual Presentation', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Group Discussion', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Speaking Exam', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Reading & Listening',
                    'weight' => 0.15,
                    'subitems' => [
                        ['name' => 'Reading Comprehension 1', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Reading Comprehension 2', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Listening Test', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];
    }

    /**
     * IEAP-4 Template: Intermediate English
     */
    private static function get_ieap4_template() {
        return [
            'name' => 'IEAP-4',
            'description' => 'Intermediate English Course',
            'level' => 'Intermediate',
            'components' => [
                [
                    'name' => 'Grammar',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Grammar Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Quiz 2', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Midterm Exam', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Grammar Final Exam', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Writing',
                    'weight' => 0.5,
                    'subitems' => [
                        ['name' => 'Writing Essay 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Writing Essay 2', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Writing Portfolio', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];
    }

    /**
     * IEAP-5 Template: Upper-Intermediate English
     */
    private static function get_ieap5_template() {
        return [
            'name' => 'IEAP-5',
            'description' => 'Upper-Intermediate English Course',
            'level' => 'Upper-Intermediate',
            'components' => [
                [
                    'name' => 'Academic Writing',
                    'weight' => 0.4,
                    'subitems' => [
                        ['name' => 'Argumentative Essay', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Research Paper', 'maxgrade' => 150, 'itemtype' => 'manual'],
                        ['name' => 'Critical Analysis Essay', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Writing Portfolio', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Grammar & Language Use',
                    'weight' => 0.25,
                    'subitems' => [
                        ['name' => 'Advanced Grammar Test 1', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Advanced Grammar Test 2', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Language Use Final', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Speaking & Presentation',
                    'weight' => 0.25,
                    'subitems' => [
                        ['name' => 'Academic Presentation', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Debate Participation', 'maxgrade' => 75, 'itemtype' => 'manual'],
                        ['name' => 'Speaking Proficiency Test', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Reading & Critical Thinking',
                    'weight' => 0.1,
                    'subitems' => [
                        ['name' => 'Critical Reading Test', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Text Analysis Project', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];
    }

    /**
     * IEAP-6 Template: Advanced English
     */
    private static function get_ieap6_template() {
        return [
            'name' => 'IEAP-6',
            'description' => 'Advanced English Course',
            'level' => 'Advanced',
            'components' => [
                [
                    'name' => 'Academic Writing & Research',
                    'weight' => 0.45,
                    'subitems' => [
                        ['name' => 'Research Proposal', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Literature Review', 'maxgrade' => 150, 'itemtype' => 'manual'],
                        ['name' => 'Research Paper Draft', 'maxgrade' => 150, 'itemtype' => 'manual'],
                        ['name' => 'Final Research Paper', 'maxgrade' => 200, 'itemtype' => 'manual'],
                        ['name' => 'Academic Writing Portfolio', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Advanced Language Skills',
                    'weight' => 0.25,
                    'subitems' => [
                        ['name' => 'Advanced Grammar & Style', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Academic Vocabulary Test', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Language Proficiency Exam', 'maxgrade' => 150, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Presentation & Communication',
                    'weight' => 0.2,
                    'subitems' => [
                        ['name' => 'Research Presentation', 'maxgrade' => 150, 'itemtype' => 'manual'],
                        ['name' => 'Academic Conference Simulation', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Professional Communication', 'maxgrade' => 75, 'itemtype' => 'manual']
                    ]
                ],
                [
                    'name' => 'Critical Analysis',
                    'weight' => 0.1,
                    'subitems' => [
                        ['name' => 'Critical Reading Analysis', 'maxgrade' => 100, 'itemtype' => 'manual'],
                        ['name' => 'Media Analysis Project', 'maxgrade' => 100, 'itemtype' => 'manual']
                    ]
                ]
            ]
        ];
    }

    /**
     * Helper function to adjust component weight
     */
    private static function adjust_component_weight($template, $component_name, $new_weight) {
        foreach ($template['components'] as &$component) {
            if ($component['name'] === $component_name) {
                $component['weight'] = $new_weight;
                break;
            }
        }
        return $template;
    }

    /**
     * Helper function to check if template has specific component
     */
    private static function has_component($template, $component_name) {
        foreach ($template['components'] as $component) {
            if ($component['name'] === $component_name) {
                return true;
            }
        }
        return false;
    }

    /**
     * Normalize weights to sum to 1.0
     */
    private static function normalize_weights($template) {
        $total_weight = 0;
        foreach ($template['components'] as $component) {
            $total_weight += $component['weight'];
        }

        if ($total_weight > 0 && abs($total_weight - 1.0) > 0.001) {
            foreach ($template['components'] as &$component) {
                $component['weight'] = $component['weight'] / $total_weight;
            }
        }

        return $template;
    }

    /**
     * Get list of available IEAP levels
     */
    public static function get_available_levels() {
        return [
            'ieap1' => 'IEAP-1 (Beginner)',
            'ieap2' => 'IEAP-2 (Elementary)',
            'ieap3' => 'IEAP-3 (Pre-Intermediate)',
            'ieap4' => 'IEAP-4 (Intermediate)',
            'ieap5' => 'IEAP-5 (Upper-Intermediate)',
            'ieap6' => 'IEAP-6 (Advanced)'
        ];
    }

    /**
     * Get IEAP level description
     */
    public static function get_level_description($level) {
        $template = self::get_template($level);
        return $template['description'] ?? '';
    }

    /**
     * Validate template structure
     */
    public static function validate_template($template) {
        $errors = [];

        if (!isset($template['name']) || empty($template['name'])) {
            $errors[] = 'Template name is required';
        }

        if (!isset($template['components']) || !is_array($template['components'])) {
            $errors[] = 'Template must have components array';
        }

        $total_weight = 0;
        foreach ($template['components'] as $component) {
            if (!isset($component['name']) || empty($component['name'])) {
                $errors[] = 'Component name is required';
            }

            if (!isset($component['weight']) || !is_numeric($component['weight'])) {
                $errors[] = 'Component weight must be numeric';
            } else {
                $total_weight += $component['weight'];
            }

            if (!isset($component['subitems']) || !is_array($component['subitems'])) {
                $errors[] = 'Component must have subitems array';
            }
        }

        if (abs($total_weight - 1.0) > 0.001) {
            $errors[] = "Component weights must sum to 1.0 (current: {$total_weight})";
        }

        return $errors;
    }
}