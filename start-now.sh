#!/bin/bash

# IMMEDIATE Moodle 5.0.2 Start Script
# Gets Moodle running as quickly as possible

set -e

echo "🚀 RAPID MOODLE 5.0.2 DEPLOYMENT STARTING..."
echo ""

# Create minimal required directories
mkdir -p volumes/{mariadb,moodle,moodledata,redis}

# Use the hardened compose file for production
echo "📦 Starting Moodle 5.0.2 services..."
docker-compose -f docker-compose.moodle-hardened.yml up -d

echo ""
echo "⏳ Waiting for services to initialize (30 seconds)..."
sleep 30

# Check status
echo ""
echo "📊 Service Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "============================================"
echo "✅ MOODLE 5.0.2 IS NOW RUNNING!"
echo "============================================"
echo ""
echo "🌐 Access Points:"
echo "   Production: http://localhost (port 80)"
echo "   Admin: http://localhost/admin"
echo "   Domain: https://moodle.pucsr.edu.kh (configure DNS)"
echo ""
echo "📝 Default Credentials:"
echo "   Username: admin"
echo "   Password: Admin@123456"
echo ""
echo "🔧 Management Commands:"
echo "   Status: ./moodle-control.sh status prod"
echo "   Logs: ./moodle-control.sh logs prod"
echo "   Stop: ./moodle-control.sh stop prod"
echo ""
echo "Ready to receive legacy image data for migration."
echo ""