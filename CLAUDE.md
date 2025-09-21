# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dockerized Moodle 5.0.2 Learning Management System setup using Bitnami images with MariaDB database and optional Redis caching for high-concurrency scenarios.

## Common Commands

### Development and Testing

```bash
# Start standard Moodle setup
docker compose -f docker-compose.moodle.yml up -d

# Start high-concurrency setup with Redis
docker compose -f docker-compose.moodle-hardened.yml up -d

# Start slim/lightweight setup (uses Alpine images where possible)
docker compose -f docker-compose.moodle-slim.yml up -d

# View logs
docker compose -f docker-compose.moodle.yml logs -f

# Stop services
docker ocmpose -f docker-compose.moodle.yml down

# Remove all data (careful!)
docker compose -f docker-compose.moodle.yml down -v
```

### Database Operations

```bash
# Backup database
docker exec moodle-mariadb mysqldump -u bn_moodle -p bitnami_moodle > backup.sql

# Access MariaDB shell
docker exec -it moodle-mariadb mysql -u bn_moodle -p
```

### Redis Operations (for high-concurrency setup)

```bash
# Test Redis connectivity
docker exec moodle-redis redis-cli --pass redis_password_change_me ping

# Monitor Redis in real-time
docker exec -it moodle-redis redis-cli --pass redis_password_change_me monitor

# Check Redis stats
docker exec moodle-redis redis-cli --pass redis_password_change_me --stat
```

### Testing Registry Access

```bash
# Test which container registries are accessible
./test-registries.sh
```

## Architecture Overview

### Compose Configurations

1. **docker-compose.moodle.yml**: Standard setup with Moodle and MariaDB
   - Uses Bitnami images from Docker Hub
   - Basic health checks and dependencies
   - Ports: 80 (HTTP), 443 (HTTPS), 3306 (MariaDB)

2. **docker-compose.moodle-hardened.yml**: Production-ready setup
   - Adds Redis for caching and session handling
   - Resource limits and reservations
   - Security hardening (capability dropping, tmpfs)
   - Bind volumes to specific directories
   - Network isolation with custom subnet

3. **docker-compose.moodle-slim.yml**: Lightweight setup
   - Uses Alpine-based images where possible (Redis, MariaDB)
   - Reduced image sizes (30-80% smaller)
   - Optimized for lower resource consumption

### Service Architecture

- **Moodle Container** (bitnami/moodle:5.0.2)
  - PHP application server
  - Apache web server
  - Connects to MariaDB for data storage
  - Optional Redis for caching

- **MariaDB Container** (bitnami/mariadb:11.4 or mariadb:11.4-alpine)
  - Primary data storage
  - UTF8MB4 character set for full Unicode support
  - Health checks for service readiness

- **Redis Container** (optional, bitnami/redis:7.2 or redis:7.2-alpine)
  - Session handling (DB 1)
  - Application cache (DB 0)
  - Request cache (DB 2)
  - Configured for 10,000 max connections

### Environment Configuration

Environment files are split by service:
- `.envs/.moodle/moodle.env`: Moodle application settings
- `.envs/.mariadb/mariadb.env`: Database configuration
- `.envs/.redis/redis.env`: Redis cache settings

Key configuration areas:
- Database connection parameters
- Admin credentials (default: admin/Admin@123456)
- PHP memory and execution limits
- Redis cache configuration
- SMTP settings (commented by default)

### Volume Management

Persistent data volumes:
- `mariadb_data`: Database files
- `moodle_data`: Application code and configuration
- `moodledata_data`: User uploads and course files
- `redis_data`: Redis persistence (AOF files)

In hardened setup, volumes are bound to local `./volumes/` directory for easier backup.

### Network Configuration

- Default: Bridge network with automatic configuration
- Hardened: Custom bridge with defined subnet (172.20.0.0/24)
- Services communicate via container names (mariadb, redis, moodle)

### Custom Theme Development

Theme files are located in `.envs/theme/` directory. Currently contains:
- `pucsr-boost/`: Custom theme based on Boost theme
  - `settings.php`: Theme configuration settings
  - `scss/`: SCSS stylesheets
  - `amd/`: AMD JavaScript modules
  - `config.php`: Theme configuration
  - `lib.php`: Theme functions

To deploy custom themes to Moodle container, they need to be mounted as volumes in the docker-compose configuration.

## Important Considerations

1. **Default Credentials**: Always change default passwords before production use
2. **HTTPS Configuration**: SSL certificates needed for production HTTPS
3. **Email Configuration**: SMTP settings required for email functionality
4. **Performance Tuning**: PHP memory limits and opcache settings can be adjusted based on load
5. **Redis Configuration**: For high-concurrency scenarios, configure Moodle cache stores via admin UI
6. **Backup Strategy**: Regular database backups recommended using provided commands