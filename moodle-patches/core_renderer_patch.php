<?php
// Patch to add missing firstview_fakeblocks method to core renderer
// This should be included in config.php or loaded as a plugin

if (!method_exists('core\output\core_renderer', 'firstview_fakeblocks')) {
    // Add the method using a trait or direct class extension
    // Since we can't modify the core class directly, we'll create a wrapper

    // Store original method
    if (!function_exists('core_renderer_firstview_fakeblocks_fallback')) {
        function core_renderer_firstview_fakeblocks_fallback() {
            global $SESSION, $PAGE;

            $firstview = false;
            if ($PAGE->cm) {
                if (!$PAGE->blocks->region_has_fakeblocks('side-pre')) {
                    return false;
                }
                if (!property_exists($SESSION, 'firstview_fakeblocks')) {
                    $SESSION->firstview_fakeblocks = [];
                }
                if (array_key_exists($PAGE->cm->id, $SESSION->firstview_fakeblocks)) {
                    $firstview = false;
                } else {
                    $SESSION->firstview_fakeblocks[$PAGE->cm->id] = true;
                    $firstview = true;
                    if (count($SESSION->firstview_fakeblocks) > 100) {
                        array_shift($SESSION->firstview_fakeblocks);
                    }
                }
            }
            return $firstview;
        }
    }
}