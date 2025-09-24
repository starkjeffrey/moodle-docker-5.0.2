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
 * PUCSR API plugin settings
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

if ($hassiteconfig) {
    $settings = new admin_settingpage('local_pucsr_api', get_string('pluginname', 'local_pucsr_api'));

    if ($ADMIN->fulltree) {
        // SIS Integration Settings
        $settings->add(new admin_setting_heading(
            'local_pucsr_api/sis_heading',
            get_string('sis_integration', 'local_pucsr_api'),
            ''
        ));

        $settings->add(new admin_setting_configcheckbox(
            'local_pucsr_api/sis_enabled',
            get_string('sis_enabled', 'local_pucsr_api'),
            get_string('sis_enabled_desc', 'local_pucsr_api'),
            0
        ));

        $settings->add(new admin_setting_configtext(
            'local_pucsr_api/sis_url',
            get_string('sis_url', 'local_pucsr_api'),
            get_string('sis_url_desc', 'local_pucsr_api'),
            '',
            PARAM_URL
        ));

        $settings->add(new admin_setting_configpasswordunmask(
            'local_pucsr_api/sis_api_key',
            get_string('sis_api_key', 'local_pucsr_api'),
            get_string('sis_api_key_desc', 'local_pucsr_api'),
            ''
        ));

        $settings->add(new admin_setting_configtext(
            'local_pucsr_api/sis_timeout',
            get_string('sis_timeout', 'local_pucsr_api'),
            get_string('sis_timeout_desc', 'local_pucsr_api'),
            30,
            PARAM_INT
        ));

        // Synchronization Settings
        $settings->add(new admin_setting_heading(
            'local_pucsr_api/sync_heading',
            get_string('sync_settings', 'local_pucsr_api'),
            ''
        ));

        $settings->add(new admin_setting_configtext(
            'local_pucsr_api/default_sync_interval',
            get_string('default_sync_interval', 'local_pucsr_api'),
            get_string('default_sync_interval_desc', 'local_pucsr_api'),
            0,
            PARAM_INT
        ));

        $settings->add(new admin_setting_configcheckbox(
            'local_pucsr_api/auto_push_grades',
            get_string('auto_push_grades', 'local_pucsr_api'),
            get_string('auto_push_grades_desc', 'local_pucsr_api'),
            0
        ));

        $settings->add(new admin_setting_configcheckbox(
            'local_pucsr_api/auto_pull_enrollments',
            get_string('auto_pull_enrollments', 'local_pucsr_api'),
            get_string('auto_pull_enrollments_desc', 'local_pucsr_api'),
            0
        ));

        // API Configuration
        $settings->add(new admin_setting_heading(
            'local_pucsr_api/api_heading',
            get_string('api_configuration', 'local_pucsr_api'),
            ''
        ));

        $settings->add(new admin_setting_configtext(
            'local_pucsr_api/api_rate_limit',
            get_string('api_rate_limit', 'local_pucsr_api'),
            get_string('api_rate_limit_desc', 'local_pucsr_api'),
            100,
            PARAM_INT
        ));

        $settings->add(new admin_setting_configcheckbox(
            'local_pucsr_api/debug_mode',
            get_string('debug_mode', 'local_pucsr_api'),
            get_string('debug_mode_desc', 'local_pucsr_api'),
            0
        ));

        // Composite Grades Settings
        $settings->add(new admin_setting_heading(
            'local_pucsr_api/composite_heading',
            get_string('composite_settings', 'local_pucsr_api'),
            ''
        ));

        $settings->add(new admin_setting_configcheckbox(
            'local_pucsr_api/enable_composite_grades',
            get_string('enable_composite_grades', 'local_pucsr_api'),
            get_string('enable_composite_grades_desc', 'local_pucsr_api'),
            1
        ));

        $settings->add(new admin_setting_configtext(
            'local_pucsr_api/default_grammar_weight',
            get_string('default_grammar_weight', 'local_pucsr_api'),
            get_string('default_grammar_weight_desc', 'local_pucsr_api'),
            0.5,
            PARAM_FLOAT
        ));

        $settings->add(new admin_setting_configtext(
            'local_pucsr_api/default_writing_weight',
            get_string('default_writing_weight', 'local_pucsr_api'),
            get_string('default_writing_weight_desc', 'local_pucsr_api'),
            0.5,
            PARAM_FLOAT
        ));
    }

    $ADMIN->add('localplugins', $settings);
}

// Add additional language strings for settings
$string['sis_integration'] = 'SIS Integration';
$string['sync_settings'] = 'Synchronization Settings';
$string['api_configuration'] = 'API Configuration';
$string['composite_settings'] = 'Composite Grades Settings';
$string['auto_push_grades'] = 'Auto-push grades';
$string['auto_push_grades_desc'] = 'Automatically push grades to SIS when they are updated';
$string['auto_pull_enrollments'] = 'Auto-pull enrollments';
$string['auto_pull_enrollments_desc'] = 'Automatically pull new enrollments from SIS';
$string['api_rate_limit'] = 'API Rate Limit';
$string['api_rate_limit_desc'] = 'Maximum API requests per minute';
$string['debug_mode'] = 'Debug Mode';
$string['debug_mode_desc'] = 'Enable debug logging for API operations';
$string['enable_composite_grades'] = 'Enable Composite Grades';
$string['enable_composite_grades_desc'] = 'Enable IEAP-4 style composite grade structures';
$string['default_grammar_weight'] = 'Default Grammar Weight';
$string['default_grammar_weight_desc'] = 'Default weight for grammar component (0.0-1.0)';
$string['default_writing_weight'] = 'Default Writing Weight';
$string['default_writing_weight_desc'] = 'Default weight for writing component (0.0-1.0)';