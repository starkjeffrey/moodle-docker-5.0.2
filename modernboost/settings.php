<?php
defined('MOODLE_INTERNAL') || die();

if ($ADMIN->fulltree) {
    $settings = new theme_boost_admin_settingspage_tabs('themesettingmodernboost', get_string('configtitle', 'theme_modernboost'));
    
    // General settings
    $page = new admin_settingpage('theme_modernboost_general', get_string('generalsettings', 'theme_modernboost'));
    
    // Brand color
    $setting = new admin_setting_configcolourpicker('theme_modernboost/brandcolor',
        get_string('brandcolor', 'theme_modernboost'),
        get_string('brandcolor_desc', 'theme_modernboost'),
        '#6366f1');
    $setting->set_updatedcallback('theme_reset_all_caches');
    $page->add($setting);
    
    // Secondary color  
    $setting = new admin_setting_configcolourpicker('theme_modernboost/secondarycolor',
        get_string('secondarycolor', 'theme_modernboost'),
        get_string('secondarycolor_desc', 'theme_modernboost'),
        '#ec4899');
    $setting->set_updatedcallback('theme_reset_all_caches');
    $page->add($setting);
    
    // Custom SCSS
    $setting = new admin_setting_configtextarea('theme_modernboost/scss',
        get_string('rawscss', 'theme_modernboost'),
        get_string('rawscss_desc', 'theme_modernboost'),
        '',
        PARAM_RAW);
    $setting->set_updatedcallback('theme_reset_all_caches');
    $page->add($setting);
    
    $settings->add($page);
}
