<?php
// theme/yourtheme/settings.php

defined('MOODLE_INTERNAL') || die();

if ($ADMIN->fulltree) {
    $settings = new theme_boost_admin_settingspage_tabs('themesettingyourtheme', get_string('configtitle', 'theme_yourtheme'));
    
    // General settings tab
    $page = new admin_settingpage('theme_yourtheme_general', get_string('generalsettings', 'theme_yourtheme'));
    
    // Brand color
    $setting = new admin_setting_configcolourpicker('theme_yourtheme/brandcolor',
        get_string('brandcolor', 'theme_yourtheme'),
        get_string('brandcolor_desc', 'theme_yourtheme'),
        '#6366f1');
    $setting->set_updatedcallback('theme_reset_all_caches');
    $page->add($setting);
    
    // Secondary color
    $setting = new admin_setting_configcolourpicker('theme_yourtheme/secondarycolor',
        get_string('secondarycolor', 'theme_yourtheme'),
        get_string('secondarycolor_desc', 'theme_yourtheme'),
        '#ec4899');
    $setting->set_updatedcallback('theme_reset_all_caches');
    $page->add($setting);
    
    // Custom CSS
    $setting = new admin_setting_configtextarea('theme_yourtheme/scss',
        get_string('rawscss', 'theme_yourtheme'),
        get_string('rawscss_desc', 'theme_yourtheme'),
        '',
        PARAM_RAW);
    $setting->set_updatedcallback('theme_reset_all_caches');
    $page->add($setting);
    
    $settings->add($page);
}