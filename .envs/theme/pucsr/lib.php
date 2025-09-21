<?php
defined('MOODLE_INTERNAL') || die();

/**
 * Returns the main SCSS content for the theme.
 */
function theme_pucsr_get_main_scss_content($theme) {
    global $CFG;

    $scss = '';
    $filename = !empty($theme->settings->preset) ? $theme->settings->preset : null;
    $fs = get_file_storage();

    $context = context_system::instance();
    $scss .= file_get_contents($CFG->dirroot . '/theme/boost/scss/preset/default.scss');

    // Add custom PUCSR SCSS
    $customscss = file_get_contents($CFG->dirroot . '/theme/pucsr/scss/pucsr.scss');
    $scss .= $customscss;

    return $scss;
}

/**
 * Get compiled CSS.
 */
function theme_pucsr_get_precompiled_css() {
    return '';
}

/**
 * Inject additional SCSS.
 */
function theme_pucsr_get_pre_scss($theme) {
    $scss = '';
    $configurable = [
        'primarycolor' => '#c8102e',     // PUCSR Red
        'secondarycolor' => '#003da5',   // PUCSR Blue
        'accentcolor' => '#f4c430',      // Gold accent
        'successcolor' => '#28a745',
        'infocolor' => '#17a2b8',
        'warningcolor' => '#ffc107',
        'dangercolor' => '#dc3545'
    ];

    foreach ($configurable as $configkey => $fallback) {
        $value = isset($theme->settings->$configkey) ? $theme->settings->$configkey : $fallback;
        $scss .= '$' . $configkey . ': ' . $value . ";\n";
    }

    return $scss;
}

/**
 * Get extra SCSS.
 */
function theme_pucsr_get_extra_scss($theme) {
    $content = '';
    if (!empty($theme->settings->scss)) {
        $content .= $theme->settings->scss;
    }
    return $content;
}