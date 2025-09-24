<?php
define('CLI_SCRIPT', true);
define('NO_DEBUG_DISPLAY', true);
require_once('/bitnami/moodle/config.php');

try {
    echo "PHP Version: " . PHP_VERSION . "\n";
    echo "Moodle loaded successfully\n";

    // Test renderer loading
    $PAGE = new moodle_page();
    $PAGE->set_context(context_system::instance());
    $PAGE->set_url('/');

    echo "PAGE created successfully\n";
    echo "Theme: " . $PAGE->theme->name . "\n";

    $output = $PAGE->get_renderer('core');
    echo "Renderer: " . get_class($output) . "\n";

    if (method_exists($output, 'firstview_fakeblocks')) {
        echo "firstview_fakeblocks: EXISTS\n";
        $result = $output->firstview_fakeblocks();
        echo "Method returns: " . ($result ? 'true' : 'false') . "\n";
    } else {
        echo "firstview_fakeblocks: MISSING\n";
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}
?>