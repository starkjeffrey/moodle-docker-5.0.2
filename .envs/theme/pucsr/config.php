<?php
defined('MOODLE_INTERNAL') || die();

$THEME->name = 'pucsr';
$THEME->sheets = [];
$THEME->parents = ['boost'];
$THEME->enable_dock = false;
$THEME->yuicssmodules = array();
$THEME->rendererfactory = 'theme_overridden_renderer_factory';
$THEME->requiredblocks = '';
$THEME->addblockposition = BLOCK_ADDBLOCK_POSITION_FLATNAV;

// Custom SCSS for PUCSR branding
$THEME->scss = function($theme) {
    return theme_pucsr_get_main_scss_content($theme);
};

$THEME->prescsscallback = 'theme_pucsr_get_pre_scss';
$THEME->extrascsscallback = 'theme_pucsr_get_extra_scss';
$THEME->precompiledcsscallback = 'theme_pucsr_get_precompiled_css';