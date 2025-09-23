<?php
defined('MOODLE_INTERNAL') || die();

$THEME->name = 'modernmoodle';
$THEME->sheets = [];
$THEME->parents = ['boost'];

$THEME->scss = function($theme) {
    return theme_modernmoodle_get_main_scss_content($theme);
};

$THEME->prescsscallback = 'theme_modernmoodle_get_pre_scss';
$THEME->extrascsscallback = 'theme_modernmoodle_get_extra_scss';
