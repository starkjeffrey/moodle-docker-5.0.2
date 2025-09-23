#!/bin/bash
# save this as: create_modern_theme.sh
# Run: chmod +x create_modern_theme.sh && ./create_modern_theme.sh

THEME_NAME="modernboost"
echo "🎨 Creating Modern Moodle Theme: $THEME_NAME"

# Create directory structure
mkdir -p $THEME_NAME/{scss/preset,templates,layout,pix,classes,lang/en,amd/src}

# Create version.php
cat > $THEME_NAME/version.php << 'EOF'
<?php
defined('MOODLE_INTERNAL') || die();

$plugin->component = 'theme_modernboost';
$plugin->version = 2024011500;
$plugin->release = 'v1.0.0';
$plugin->requires = 2022112800; // Moodle 4.1+
$plugin->maturity = MATURITY_STABLE;
$plugin->dependencies = ['theme_boost' => 2022112800];
EOF

# Create config.php
cat > $THEME_NAME/config.php << 'EOF'
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
EOF

# Create lib.php
cat > $THEME_NAME/lib.php << 'EOF'
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
EOF

# Create the main SCSS file
cat > $THEME_NAME/scss/preset/default.scss << 'EOF'
// Modern Color Palette
$primary: #6366f1 !default;
$secondary: #ec4899 !default;
$success: #10b981 !default;
$info: #0ea5e9 !default;
$warning: #f59e0b !default;
$danger: #ef4444 !default;
$light: #f9fafb !default;
$dark: #111827 !default;

// Gradients
$gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
$gradient-secondary: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
$gradient-hero: linear-gradient(135deg, #4f46e5 0%, #7c3aed 50%, #a855f7 100%);

// Typography
$font-family-base: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
$headings-font-family: 'Poppins', $font-family-base;
$headings-font-weight: 600;

// Spacing
$spacer: 1rem;
$border-radius: 0.75rem;
$border-radius-lg: 1rem;
$border-radius-sm: 0.5rem;
$card-border-radius: $border-radius-lg;

// Shadows
$box-shadow-sm: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
$box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
$box-shadow-lg: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);

// Import Bootstrap and Boost
@import "../../boost/scss/preset/default";
@import "../../boost/scss/moodle";
EOF

# Create post.scss with all the custom styles
cat > $THEME_NAME/scss/post.scss << 'EOF'
// Google Fonts
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Poppins:wght@600;700&display=swap');

// Animated Gradient Background
.hero-gradient {
    background: $gradient-hero;
    background-size: 200% 200%;
    animation: gradientShift 15s ease infinite;
}

@keyframes gradientShift {
    0%, 100% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
}

// Glass Morphism Effect
.card {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    border: 1px solid rgba(255, 255, 255, 0.2);
    box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.1);
    border-radius: $border-radius-lg;
    transition: all 0.3s ease;
    
    &:hover {
        transform: translateY(-5px);
        box-shadow: 0 12px 40px 0 rgba(31, 38, 135, 0.15);
    }
}

// Course Cards with Hover Effects
.course-card {
    position: relative;
    overflow: hidden;
    border-radius: $border-radius-lg;
    transition: all 0.3s ease;
    
    &::before {
        content: '';
        position: absolute;
        top: 0;
        left: -100%;
        width: 100%;
        height: 100%;
        background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
        transition: left 0.7s;
    }
    
    &:hover::before {
        left: 100%;
    }
    
    &:hover {
        transform: scale(1.02);
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
    }
}

// Navigation Bar
.navbar {
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    box-shadow: 0 2px 20px rgba(0, 0, 0, 0.05);
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
}

// Buttons with Gradient
.btn-primary {
    background: $gradient-primary;
    border: none;
    box-shadow: 0 4px 15px 0 rgba(102, 126, 234, 0.4);
    transition: all 0.3s ease;
    
    &:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 20px 0 rgba(102, 126, 234, 0.6);
    }
}

// Dark Mode Support
@media (prefers-color-scheme: dark) {
    body {
        background: #0f172a;
        color: #e2e8f0;
    }
    
    .card {
        background: rgba(30, 41, 59, 0.95);
        border-color: rgba(255, 255, 255, 0.1);
    }
    
    .navbar {
        background: rgba(15, 23, 42, 0.95);
        border-bottom-color: rgba(255, 255, 255, 0.1);
    }
}

// Responsive Design
@media (max-width: 768px) {
    .card {
        border-radius: $border-radius;
    }
    
    .navbar-brand {
        font-size: 1.2rem;
    }
}
EOF

# Create settings.php
cat > $THEME_NAME/settings.php << 'EOF'
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
EOF

# Create language file
cat > $THEME_NAME/lang/en/theme_modernboost.php << 'EOF'
<?php
defined('MOODLE_INTERNAL') || die();

$string['pluginname'] = 'Modern Boost';
$string['configtitle'] = 'Modern Boost Settings';
$string['generalsettings'] = 'General Settings';
$string['brandcolor'] = 'Brand Color';
$string['brandcolor_desc'] = 'The main brand color used throughout the theme.';
$string['secondarycolor'] = 'Secondary Color';
$string['secondarycolor_desc'] = 'The secondary accent color.';
$string['rawscss'] = 'Raw SCSS';
$string['rawscss_desc'] = 'Add custom SCSS code to further customize the theme.';
$string['choosereadme'] = 'Modern Boost is a beautiful, modern theme built on top of Boost with gradients, animations, and glass morphism effects.';
EOF

# Create a ZIP file
echo "📦 Creating theme package..."
zip -r modernboost.zip $THEME_NAME/

echo "✅ Theme created successfully!"
echo ""
echo "📁 Files created in: $THEME_NAME/"
echo "📦 Package created: modernboost.zip"
echo ""
echo "Installation: Upload modernboost.zip via Site admin > Plugins > Install plugins"
