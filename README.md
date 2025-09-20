# Moodle 5.0.2 Docker Setup

This Docker Compose setup uses the official Bitnami Moodle 5.0.2 image with MariaDB.

## Features Incorporated from Bitnami

- **Official Bitnami Images**: Using `bitnami/moodle:5.0.2-debian-12-r1` and `bitnami/mariadb:11.4`
- **Health Checks**: Both services include health checks for better reliability
- **Optimized Character Set**: UTF8MB4 support for better Unicode handling
- **Dependency Management**: Moodle waits for MariaDB to be healthy before starting
- **Standard Ports**: HTTP on port 80, HTTPS on port 443
- **Optimized PHP Settings**: Increased memory limits for better performance

## Quick Start

1. Start the services:
   ```bash
   docker-compose -f docker-compose.moodle.yml up -d
   ```

2. Access Moodle:
   - HTTP: http://localhost
   - HTTPS: https://localhost

3. Default admin credentials:
   - Username: admin
   - Password: Admin@123456

## Environment Files

- `.envs/.moodle/moodle.env` - Moodle configuration
- `.envs/.mariadb/mariadb.env` - MariaDB configuration

## Production Considerations

1. Change all default passwords in the environment files
2. Remove or comment out `ALLOW_EMPTY_PASSWORD` settings
3. Configure SSL certificates for HTTPS
4. Set up proper SMTP settings for email functionality
5. Adjust PHP memory limits based on your needs

## Volumes

- `mariadb_data` - MariaDB database files
- `moodle_data` - Moodle application files
- `moodledata_data` - Moodle user data and uploads

## Useful Commands

```bash
# Start services
docker-compose -f docker-compose.moodle.yml up -d

# Stop services
docker-compose -f docker-compose.moodle.yml down

# View logs
docker-compose -f docker-compose.moodle.yml logs -f

# Backup database
docker exec moodle-mariadb mysqldump -u bn_moodle -p bitnami_moodle > backup.sql

# Remove all data (careful!)
docker-compose -f docker-compose.moodle.yml down -v
```