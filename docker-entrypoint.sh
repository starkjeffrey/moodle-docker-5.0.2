#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database connection..."
until mysql -h"$MOODLE_DATABASE_HOST" -u"$MOODLE_DATABASE_USER" -p"$MOODLE_DATABASE_PASSWORD" -e "SELECT 1" &> /dev/null; do
    echo "Database is unavailable - sleeping"
    sleep 5
done
echo "Database is up - continuing..."

# Check if Moodle is already installed
if [ ! -f /var/www/html/config.php ]; then
    echo "Installing Moodle..."

    # Create config.php
    php /var/www/html/admin/cli/install.php \
        --wwwroot="$MOODLE_SITE_URL" \
        --dataroot="$MOODLE_DATA_DIR" \
        --dbtype="$MOODLE_DATABASE_TYPE" \
        --dbhost="$MOODLE_DATABASE_HOST" \
        --dbname="$MOODLE_DATABASE_NAME" \
        --dbuser="$MOODLE_DATABASE_USER" \
        --dbpass="$MOODLE_DATABASE_PASSWORD" \
        --dbprefix="$MOODLE_DATABASE_PREFIX" \
        --fullname="$MOODLE_SITE_NAME" \
        --shortname="Moodle" \
        --adminuser="$MOODLE_ADMIN_USER" \
        --adminpass="$MOODLE_ADMIN_PASSWORD" \
        --adminemail="$MOODLE_ADMIN_EMAIL" \
        --agree-license \
        --non-interactive

    # Configure Redis if available
    if [ -n "$MOODLE_REDIS_HOST" ]; then
        echo "Configuring Redis cache..."
        cat >> /var/www/html/config.php <<EOF

// Redis cache configuration
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '$MOODLE_REDIS_HOST';
\$CFG->session_redis_port = $MOODLE_REDIS_PORT;
\$CFG->session_redis_database = 0;
\$CFG->session_redis_prefix = 'moodle_session_';

// Redis cache stores
\$CFG->cacheconfig = array(
    'default_application' => array(
        'name' => 'redis',
        'plugin' => 'redis',
        'configuration' => array(
            'server' => '$MOODLE_REDIS_HOST:$MOODLE_REDIS_PORT',
            'prefix' => 'moodle_app_',
            'password' => getenv('MOODLE_REDIS_PASSWORD') ?: '',
        ),
    ),
    'default_session' => array(
        'name' => 'redis',
        'plugin' => 'redis',
        'configuration' => array(
            'server' => '$MOODLE_REDIS_HOST:$MOODLE_REDIS_PORT',
            'prefix' => 'moodle_sess_',
            'password' => getenv('MOODLE_REDIS_PASSWORD') ?: '',
        ),
    ),
    'default_request' => array(
        'name' => 'redis',
        'plugin' => 'redis',
        'configuration' => array(
            'server' => '$MOODLE_REDIS_HOST:$MOODLE_REDIS_PORT',
            'prefix' => 'moodle_req_',
            'password' => getenv('MOODLE_REDIS_PASSWORD') ?: '',
        ),
    ),
);
EOF
    fi

    echo "Moodle installation complete!"
else
    echo "Moodle is already installed."
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html /var/moodledata

# Start Apache
exec "$@"