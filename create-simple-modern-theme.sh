#!/bin/bash
# Simple Modern Moodle Theme Creator

THEME_NAME="modernmoodle"
echo "🎨 Creating Simple Modern Theme: $THEME_NAME"

# Create directory structure
mkdir -p $THEME_NAME/{scss,lang/en}

# Create version.php
cat > $THEME_NAME/version.php << 'EOF'
<?php
defined('MOODLE_INTERNAL') || die();

$plugin->component = 'theme_modernmoodle';
$plugin->version = 2024092300;
$plugin->release = 'v1.0.0';
$plugin->requires = 2024041500; // Moodle 5.0+
$plugin->maturity = MATURITY_STABLE;
$plugin->dependencies = ['theme_boost' => 2024041500];
EOF

# Create config.php - minimal and safe
cat > $THEME_NAME/config.php << 'EOF'
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
EOF

# Create lib.php - simplified
cat > $THEME_NAME/lib.php << 'EOF'
<?php
defined('MOODLE_INTERNAL') || die();

function theme_modernmoodle_get_main_scss_content($theme) {
    global $CFG;

    $scss = '';
    $fs = get_file_storage();

    // Get parent theme SCSS
    $scss .= file_get_contents($CFG->dirroot . '/theme/boost/scss/preset/default.scss');

    // Add our custom styles
    $customscss = file_exists($CFG->dirroot . '/theme/modernmoodle/scss/custom.scss')
        ? file_get_contents($CFG->dirroot . '/theme/modernmoodle/scss/custom.scss') : '';

    return $scss . "\n" . $customscss;
}

function theme_modernmoodle_get_pre_scss($theme) {
    $scss = '';

    // Modern color variables
    $scss .= '$primary: #6366f1;' . "\n";
    $scss .= '$secondary: #ec4899;' . "\n";
    $scss .= '$success: #10b981;' . "\n";
    $scss .= '$info: #0ea5e9;' . "\n";
    $scss .= '$warning: #f59e0b;' . "\n";
    $scss .= '$danger: #ef4444;' . "\n";

    return $scss;
}

function theme_modernmoodle_get_extra_scss($theme) {
    return !empty($theme->settings->scss) ? $theme->settings->scss : '';
}
EOF

# Create custom SCSS with modern styling
cat > $THEME_NAME/scss/custom.scss << 'EOF'
// Import Google Fonts
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

// Modern styling
body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    background-attachment: fixed;
}

// Navigation
.navbar {
    background: rgba(255, 255, 255, 0.95) !important;
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
    border: none;
}

// Cards with modern styling
.card {
    border-radius: 15px;
    border: none;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    transition: transform 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
}

// Buttons
.btn-primary {
    background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
    border: none;
    border-radius: 10px;
    padding: 10px 20px;
    font-weight: 500;
    transition: all 0.3s ease;
    box-shadow: 0 4px 15px rgba(99, 102, 241, 0.3);
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(99, 102, 241, 0.4);
}

// Course cards
.coursebox {
    border-radius: 15px;
    overflow: hidden;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    transition: transform 0.3s ease;
}

.coursebox:hover {
    transform: scale(1.02);
}

// Dashboard improvements
#page-my-index .dashboard-card {
    background: rgba(255, 255, 255, 0.9);
    border-radius: 15px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

// Header styling
.page-header-headings h1 {
    color: white;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
    font-weight: 600;
}

// Content area
#region-main {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 20px;
    padding: 30px;
    margin: 20px 0;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    backdrop-filter: blur(10px);
}

// Responsive improvements
@media (max-width: 768px) {
    #region-main {
        border-radius: 15px;
        padding: 20px;
        margin: 10px;
    }

    .card {
        border-radius: 10px;
    }
}
EOF

# Create language file
cat > $THEME_NAME/lang/en/theme_modernmoodle.php << 'EOF'
<?php
defined('MOODLE_INTERNAL') || die();

$string['pluginname'] = 'Modern Moodle';
$string['configtitle'] = 'Modern Moodle Theme Settings';
$string['choosereadme'] = 'Modern Moodle is a beautiful, contemporary theme with modern design elements and smooth animations.';
EOF

echo "✅ Simple Modern Theme created successfully!"
echo "📁 Files created in: $THEME_NAME/"
echo "🚀 This theme is compatible with Moodle 5.0+"