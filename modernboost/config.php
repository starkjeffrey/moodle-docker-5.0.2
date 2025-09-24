<?php
defined('MOODLE_INTERNAL') || die();

$THEME->name = 'modernboost';
$THEME->sheets = [];
$THEME->parents = ['boost'];
$THEME->enable_dock = false;

$THEME->scss = function($theme) {
    return theme_modernboost_get_main_scss_content($theme);
};

$THEME->prescsscallback = 'theme_modernboost_get_pre_scss';
$THEME->extrascsscallback = 'theme_modernboost_get_extra_scss';

$THEME->requiredblocks = '';
$THEME->addblockposition = BLOCK_ADDBLOCK_POSITION_FLATNAV;
$THEME->iconsystem = \core\output\icon_system::FONTAWESOME;
$THEME->haseditswitch = true;
$THEME->usescourseindex = true;
$THEME->primarynav = true;
