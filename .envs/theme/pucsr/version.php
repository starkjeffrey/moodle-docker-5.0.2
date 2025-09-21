<?php
defined('MOODLE_INTERNAL') || die();

$plugin->component = 'theme_pucsr';
$plugin->version   = 2024092100;
$plugin->requires  = 2023100900;
$plugin->maturity  = MATURITY_STABLE;
$plugin->release   = '1.0';
$plugin->dependencies = [
    'theme_boost' => 2023100900
];