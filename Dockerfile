# Multi-stage build for optimized Moodle image
FROM php:8.4-apache AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libxml2-dev \
    libicu-dev \
    libldap2-dev \
    libpq-dev \
    libxslt1-dev \
    ghostscript \
    cron \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions required by Moodle
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    zip \
    intl \
    xml \
    soap \
    opcache \
    mysqli \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    xsl \
    exif \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install ldap

# Install Redis extension for PHP
RUN pecl install redis && docker-php-ext-enable redis

# Configure Apache
RUN a2enmod rewrite expires headers
COPY apache-config.conf /etc/apache2/sites-available/000-default.conf

# Set PHP configuration for Moodle
RUN { \
    echo 'memory_limit=512M'; \
    echo 'upload_max_filesize=200M'; \
    echo 'post_max_size=200M'; \
    echo 'max_execution_time=300'; \
    echo 'max_input_time=300'; \
    echo 'max_input_vars=5000'; \
    } > /usr/local/etc/php/conf.d/moodle.ini

# OPcache configuration for performance
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

# Download and extract Moodle
ARG MOODLE_VERSION=5.0.2
WORKDIR /var/www

RUN curl -L https://github.com/moodle/moodle/archive/refs/tags/v${MOODLE_VERSION}.tar.gz | tar xz \
    && mv moodle-${MOODLE_VERSION} html \
    && mkdir -p /var/moodledata \
    && chown -R www-data:www-data /var/www/html /var/moodledata \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/moodledata

# Create config directory
RUN mkdir -p /var/www/html/config

# Copy initialization scripts
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Environment variables for Moodle configuration
ENV MOODLE_DATABASE_TYPE=mariadb \
    MOODLE_DATABASE_HOST=mariadb \
    MOODLE_DATABASE_NAME=moodle \
    MOODLE_DATABASE_USER=moodle \
    MOODLE_DATABASE_PASSWORD=moodlepassword \
    MOODLE_DATABASE_PREFIX=mdl_ \
    MOODLE_ADMIN_USER=admin \
    MOODLE_ADMIN_PASSWORD=Admin@123456 \
    MOODLE_ADMIN_EMAIL=admin@example.com \
    MOODLE_SITE_NAME="Moodle LMS" \
    MOODLE_SITE_URL=http://localhost \
    MOODLE_DATA_DIR=/var/moodledata \
    MOODLE_REDIS_HOST=redis \
    MOODLE_REDIS_PORT=6379

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Expose ports
EXPOSE 80 443

# Set working directory
WORKDIR /var/www/html

# Run as www-data user for security
USER www-data

# Entry point
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]

# ===========================
# Production stage
# ===========================
FROM base AS production
# Production optimizations
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ===========================
# Alpine-based slim version
# ===========================
FROM alpine:3.19 AS moodle-alpine

# Install packages
RUN apk add --no-cache \
    apache2 \
    php82 \
    php82-apache2 \
    php82-session \
    php82-json \
    php82-xml \
    php82-mbstring \
    php82-zip \
    php82-gd \
    php82-curl \
    php82-opcache \
    php82-ctype \
    php82-pdo \
    php82-pdo_mysql \
    php82-pdo_pgsql \
    php82-dom \
    php82-xmlreader \
    php82-xmlwriter \
    php82-tokenizer \
    php82-soap \
    php82-fileinfo \
    php82-simplexml \
    php82-intl \
    php82-sodium \
    php82-exif \
    php82-pecl-redis \
    curl \
    wget \
    git \
    ghostscript

# Configure Apache
RUN mkdir -p /run/apache2 \
    && chown -R apache:apache /run/apache2 \
    && sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/apache2/httpd.conf \
    && sed -i 's/#LoadModule session_module/LoadModule session_module/' /etc/apache2/httpd.conf \
    && sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/httpd.conf

# Download Moodle
ARG MOODLE_VERSION=5.0.2
WORKDIR /var/www

RUN wget -qO- https://github.com/moodle/moodle/archive/refs/tags/v${MOODLE_VERSION}.tar.gz | tar xz \
    && mv moodle-${MOODLE_VERSION} localhost \
    && mkdir -p /var/moodledata \
    && chown -R apache:apache /var/www/localhost /var/moodledata \
    && chmod -R 755 /var/www/localhost \
    && chmod -R 777 /var/moodledata

# PHP Configuration
RUN echo "memory_limit=512M" >> /etc/php82/php.ini \
    && echo "upload_max_filesize=200M" >> /etc/php82/php.ini \
    && echo "post_max_size=200M" >> /etc/php82/php.ini \
    && echo "max_execution_time=300" >> /etc/php82/php.ini \
    && echo "max_input_vars=5000" >> /etc/php82/php.ini

COPY docker-entrypoint-alpine.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["httpd", "-D", "FOREGROUND"]