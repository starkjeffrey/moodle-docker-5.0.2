<?php
define('CLI_SCRIPT', true);
require_once('config.php');

echo "Debug Theme Information\n";
echo "======================\n";
echo "Current theme: " . $CFG->theme . "\n";

$PAGE->set_context(context_system::instance());
$PAGE->set_url('/debug_theme.php');

echo "Theme from PAGE: " . $PAGE->theme->name . "\n";

$output = $PAGE->get_renderer('core');
echo "Renderer class: " . get_class($output) . "\n";

if (method_exists($output, 'firstview_fakeblocks')) {
    echo "firstview_fakeblocks method: EXISTS\n";
} else {
    echo "firstview_fakeblocks method: MISSING\n";
}

// Check parent classes
$reflection = new ReflectionClass($output);
echo "Parent classes:\n";
$parent = $reflection->getParentClass();
while ($parent) {
    echo "- " . $parent->getName() . "\n";
    if ($parent->hasMethod('firstview_fakeblocks')) {
        echo "  -> has firstview_fakeblocks method\n";
    }
    $parent = $parent->getParentClass();
}

// Check if we can instantiate the theme renderer directly
try {
    $theme_renderer_class = 'theme_' . $PAGE->theme->name . '\output\core_renderer';
    if (class_exists($theme_renderer_class)) {
        echo "Theme renderer class exists: $theme_renderer_class\n";
        $theme_renderer = new $theme_renderer_class($PAGE, '');
        if (method_exists($theme_renderer, 'firstview_fakeblocks')) {
            echo "Theme renderer HAS firstview_fakeblocks method\n";
        } else {
            echo "Theme renderer MISSING firstview_fakeblocks method\n";
        }
    } else {
        echo "Theme renderer class NOT FOUND: $theme_renderer_class\n";
    }
} catch (Exception $e) {
    echo "Error instantiating theme renderer: " . $e->getMessage() . "\n";
}
?>