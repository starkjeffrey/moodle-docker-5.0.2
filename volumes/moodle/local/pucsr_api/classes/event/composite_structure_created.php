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
 * Event for composite structure creation
 *
 * @package    local_pucsr_api
 * @copyright  2025 PUCSR
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

namespace local_pucsr_api\event;

use core\event\base;

/**
 * Event fired when a composite grade structure is created
 */
class composite_structure_created extends base {

    /**
     * Initialize the event
     */
    protected function init() {
        $this->data['crud'] = 'c';
        $this->data['edulevel'] = self::LEVEL_TEACHING;
        $this->data['objecttable'] = 'grade_categories';
    }

    /**
     * Return the event name
     */
    public static function get_name() {
        return get_string('event_composite_structure_created', 'local_pucsr_api');
    }

    /**
     * Return the event description
     */
    public function get_description() {
        return "User {$this->userid} created composite grade structure '{$this->other['structure_name']}' " .
               "in course {$this->courseid}";
    }

    /**
     * Get the URL for this event
     */
    public function get_url() {
        return new \moodle_url('/grade/edit/tree/index.php', ['courseid' => $this->courseid]);
    }

    /**
     * Custom validation
     */
    protected function validate_data() {
        parent::validate_data();

        if (!isset($this->other['structure_name'])) {
            throw new \coding_exception('The \'structure_name\' value must be set in other.');
        }
    }
}