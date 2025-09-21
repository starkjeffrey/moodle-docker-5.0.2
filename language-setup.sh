#!/bin/bash

# Bilingual Setup Script for Moodle - Khmer and English
# For PUCSR Moodle Installation

set -e

echo "🌐 Setting up Bilingual Support (Khmer + English)..."

# Wait for Moodle to be running
until docker exec moodle-app php -v > /dev/null 2>&1; do
    echo "Waiting for Moodle container..."
    sleep 5
done

# Install Khmer language pack via Moodle CLI
echo "📦 Installing Khmer language pack..."

docker exec moodle-app bash -c "
    cd /bitnami/moodle

    # Download Khmer language pack
    echo 'Downloading Khmer language pack...'
    php admin/cli/install_language.php --lang=km --agree-license || {
        # Alternative method if CLI doesn't work
        cd /bitnami/moodle/lang
        wget -q https://download.moodle.org/download.php/direct/langpack/5.0/km.zip
        unzip -q km.zip
        rm km.zip
    }

    # Set language configuration
    php admin/cli/cfg.php --name=lang --set=en
    php admin/cli/cfg.php --name=langmenu --set=1
    php admin/cli/cfg.php --name=langlist --set='en,km'
    php admin/cli/cfg.php --name=langcache --set=1

    # Enable multilang content filter
    php admin/cli/cfg.php --component=filter_multilang --name=enable --set=1

    # Purge caches
    php admin/cli/purge_caches.php
"

# Update database for Khmer collation support
echo "🗄️ Configuring database for Khmer support..."

docker exec moodle-mariadb mysql -u root -p\${MARIADB_ROOT_PASSWORD} -e "
    ALTER DATABASE bitnami_moodle CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
"

# Create language switcher configuration
echo "🔄 Creating language switcher configuration..."

cat > /tmp/lang_config.php <<'EOF'
<?php
// Language configuration for PUCSR Moodle
// This file configures bilingual support for Khmer and English

// Available languages
$CFG->langlist = 'en,km';

// Default language
$CFG->lang = 'en';

// Show language menu
$CFG->langmenu = true;

// Language menu location
$CFG->langmenuinsidecourse = true;

// Cache language strings
$CFG->langcache = true;

// Multilang settings
$CFG->filter_multilang_force_old = false;

// Language strings customization
$string['sitename'] = '{mlang en}PUCSR Moodle{mlang}{mlang km}PUCSR មូឌូល{mlang}';
$string['welcome'] = '{mlang en}Welcome to PUCSR Learning Platform{mlang}{mlang km}សូមស្វាគមន៍មកកាន់វេទិកាសិក្សា PUCSR{mlang}';
EOF

docker cp /tmp/lang_config.php moodle-app:/bitnami/moodle/local/

# Install additional Khmer fonts
echo "🔤 Installing Khmer fonts..."

docker exec moodle-app bash -c "
    # Install Khmer Unicode fonts
    apt-get update && apt-get install -y \
        fonts-khmeros \
        fonts-khmeros-core \
        fonts-noto-cjk \
        ttf-khmeros-core || true

    # For Alpine-based images
    apk add --no-cache font-noto font-noto-extra || true
"

echo ""
echo "========================================="
echo "✅ BILINGUAL SETUP COMPLETE!"
echo "========================================="
echo ""
echo "🌐 Language Configuration:"
echo "   Primary: English (en)"
echo "   Secondary: Khmer (km)"
echo ""
echo "📝 To use multilang content in Moodle:"
echo '   {mlang en}English text{mlang}{mlang km}អត្ថបទភាសាខ្មែរ{mlang}'
echo ""
echo "🔧 Manual Configuration Steps:"
echo "1. Login to Moodle as admin"
echo "2. Go to Site administration > Language > Language settings"
echo "3. Verify Khmer (km) is in installed language packs"
echo "4. Go to Site administration > Plugins > Filters > Multi-Language Content"
echo "5. Enable the filter and set to 'On' for content and headings"
echo ""
echo "👥 User Language Selection:"
echo "Users can switch languages using the language menu in the navigation bar"
echo ""