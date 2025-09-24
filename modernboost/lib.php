<?php
defined('MOODLE_INTERNAL') || die();

function theme_modernboost_get_main_scss_content($theme) {
    global $CFG;
    
    $scss = '';
    $filename = !empty($theme->settings->preset) ? $theme->settings->preset : null;
    $fs = get_file_storage();
    
    $context = context_system::instance();
    if ($filename == 'default.scss') {
        $scss .= file_get_contents($CFG->dirroot . '/theme/modernboost/scss/preset/default.scss');
    } else if ($filename && ($presetfile = $fs->get_file($context->id, 'theme_modernboost', 'preset', 0, '/', $filename))) {
        $scss .= $presetfile->get_content();
    } else {
        $scss .= file_get_contents($CFG->dirroot . '/theme/boost/scss/preset/default.scss');
    }
    
    $pre = file_exists($CFG->dirroot . '/theme/modernboost/scss/pre.scss') 
        ? file_get_contents($CFG->dirroot . '/theme/modernboost/scss/pre.scss') : '';
    $post = file_exists($CFG->dirroot . '/theme/modernboost/scss/post.scss')
        ? file_get_contents($CFG->dirroot . '/theme/modernboost/scss/post.scss') : '';
    
    return $pre . "\n" . $scss . "\n" . $post;
}

function theme_modernboost_get_pre_scss($theme) {
    $scss = '';
    $configurable = [
        'brandcolor' => '#6366f1',
        'secondarycolor' => '#ec4899',
    ];
    
    foreach ($configurable as $name => $default) {
        $setting = isset($theme->settings->$name) ? $theme->settings->$name : $default;
        $scss .= '$' . $name . ': ' . $setting . ";\n";
    }
    
    return $scss;
}

function theme_modernboost_get_extra_scss($theme) {
    return !empty($theme->settings->scss) ? $theme->settings->scss : '';
}
