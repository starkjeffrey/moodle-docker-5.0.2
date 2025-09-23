<?php
defined('MOODLE_INTERNAL') || die();

function theme_modernmoodle_get_main_scss_content($theme) {
    global $CFG;

    $scss = '';
    $fs = get_file_storage();

    // Get parent theme SCSS
    $scss .= file_get_contents($CFG->dirroot . '/theme/boost/scss/preset/default.scss');

    // Add our custom styles
    $customscss = file_exists($CFG->dirroot . '/theme/modernmoodle/scss/custom.scss')
        ? file_get_contents($CFG->dirroot . '/theme/modernmoodle/scss/custom.scss') : '';

    return $scss . "\n" . $customscss;
}

function theme_modernmoodle_get_pre_scss($theme) {
    $scss = '';

    // Modern color variables
    $scss .= '$primary: #6366f1;' . "\n";
    $scss .= '$secondary: #ec4899;' . "\n";
    $scss .= '$success: #10b981;' . "\n";
    $scss .= '$info: #0ea5e9;' . "\n";
    $scss .= '$warning: #f59e0b;' . "\n";
    $scss .= '$danger: #ef4444;' . "\n";

    return $scss;
}

function theme_modernmoodle_get_extra_scss($theme) {
    return !empty($theme->settings->scss) ? $theme->settings->scss : '';
}
