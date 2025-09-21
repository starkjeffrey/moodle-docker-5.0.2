#!/bin/bash

# Quick Start Script for Moodle 5.0.2
set -e

echo "🚀 Starting Moodle 5.0.2 deployment..."

# Create necessary directories
mkdir -p /data/moodle/{mariadb,app,data,redis}
mkdir -p traefik/letsencrypt
mkdir -p backup-system/logs

# Set permissions
chmod 777 /data/moodle/{data,redis}

# Create basic environment file if not exists
if [ ! -f .env ]; then
cat > .env <<EOF
DB_ROOT_PASSWORD=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=Admin@2024!
S3_BACKUP_BUCKET=
S3_ACCESS_KEY=
S3_SECRET_KEY=
GDRIVE_FOLDER_ID=
EOF
echo "✅ Environment file created"
fi

# Pull images first for faster startup
echo "📦 Pulling Docker images..."
docker pull mariadb:11.4
docker pull redis:7.2-alpine
docker pull bitnami/moodle:5.0.2
docker pull traefik:v3.0

# Start services using the standard Bitnami images (fastest option)
echo "🔧 Starting services..."
docker-compose -f docker-compose.moodle-hardened.yml up -d

# Wait for MariaDB to be ready
echo "⏳ Waiting for MariaDB to be ready..."
until docker exec moodle-mariadb mysqladmin ping -h localhost --silent; do
    sleep 2
done

echo "✅ MariaDB is ready"

# Check Moodle status
echo "🔍 Checking Moodle status..."
sleep 10

if docker ps | grep -q moodle-app; then
    echo "✅ Moodle container is running"
else
    echo "❌ Moodle container failed to start"
    docker logs moodle-app
    exit 1
fi

echo ""
echo "========================================="
echo "✅ MOODLE 5.0.2 IS NOW RUNNING!"
echo "========================================="
echo ""
echo "Access URLs:"
echo "  Local: http://localhost"
echo "  Domain: https://moodle.pucsr.edu.kh"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: Admin@2024!"
echo ""
echo "Commands:"
echo "  View logs: docker-compose -f docker-compose.moodle-hardened.yml logs -f"
echo "  Stop: docker-compose -f docker-compose.moodle-hardened.yml down"
echo ""
echo "Note: Update DNS to point moodle.pucsr.edu.kh to this server's IP"
echo ""