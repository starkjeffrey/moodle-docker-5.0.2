# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dockerized Moodle 5.0.2 Learning Management System using Bitnami images with MariaDB database and optional Redis caching for high-concurrency scenarios.

## Common Commands

### Development and Testing

```bash
# Start standard Moodle setup
docker compose -f docker-compose.moodle.yml up -d

# Start high-concurrency setup with Redis
docker compose -f docker-compose.moodle-hardened.yml up -d

# Start slim/lightweight setup (uses Alpine images where possible)
docker compose -f docker-compose.moodle-slim.yml up -d

# Start Moodle with AI capabilities (Ollama + LiteLLM)
docker compose -f docker-compose.moodle-ai.yml up -d

# View logs
docker compose -f docker-compose.moodle.yml logs -f

# Stop services
docker compose -f docker-compose.moodle.yml down

# Remove all data (careful!)
docker compose -f docker-compose.moodle.yml down -v
```

### Database Operations

```bash
# Backup database
docker exec moodle-mariadb mysqldump -u bn_moodle -pbitnami_moodle bitnami_moodle > backup.sql

# Access MariaDB shell
docker exec -it moodle-mariadb mysql -u bn_moodle -pbitnami_moodle
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
   - Bind volumes to `./volumes/` directory
   - Network isolation with custom subnet (172.20.0.0/24)

3. **docker-compose.moodle-slim.yml**: Lightweight setup
   - Uses Alpine-based images where possible (Redis, MariaDB)
   - Reduced image sizes (30-80% smaller)
   - Optimized for lower resource consumption

4. **docker-compose.moodle-ai.yml**: Moodle with AI capabilities
   - Includes Ollama for local LLM inference
   - LiteLLM proxy for OpenAI-compatible API
   - All services on same network for integration
   - Ports: 11434 (Ollama), 4000 (LiteLLM API)

### Service Architecture

- **Moodle Container** (bitnami/moodle:5.0.2)
  - PHP application server with Apache
  - Connects to MariaDB for data storage
  - Optional Redis for caching
  - Health check via PHP script
  - Ports: 8080 (HTTP internal), 8443 (HTTPS internal)

- **MariaDB Container** (bitnami/mariadb:11.4 or mariadb:11.4-alpine)
  - Primary data storage
  - UTF8MB4 character set for full Unicode support
  - Health checks using Bitnami scripts
  - Port: 3306 (internal)

- **Redis Container** (optional, bitnami/redis:7.2 or redis:7.2-alpine)
  - Session handling (DB 1)
  - Application cache (DB 0)
  - Request cache (DB 2)
  - Configured for 10,000 max connections
  - AOF persistence enabled

- **Ollama Container** (optional, ollama/ollama:latest in AI setup)
  - Local LLM inference engine
  - Supports multiple model formats
  - Port: 11434 for API access

- **LiteLLM Container** (optional, ghcr.io/berriai/litellm:latest in AI setup)
  - OpenAI-compatible API proxy
  - Connects to Ollama backend
  - Default model: qwen2-7b-instruct
  - Port: 4000 for API access

### Environment Configuration

Environment files are split by service:
- `.envs/.moodle/moodle.env`: Moodle application settings
  - Admin credentials (default: admin/Admin@123456)
  - PHP settings: 512M memory, 300s execution time, 200M upload
  - OPcache: 256M memory, 10000 files
- `.envs/.mariadb/mariadb.env`: Database configuration
  - Database: bitnami_moodle
  - User: bn_moodle
- `.envs/.redis/redis.env`: Redis cache settings
  - Max clients: 10000
  - Memory policy: allkeys-lru (1GB max)
  - Persistence: AOF with everysec fsync

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

Theme files are located in `.envs/theme/` directory:
- `pucsr/`: Complete custom theme with version.php, config.php, lib.php, lang files
- `pucsr-boost/`: Custom theme based on Boost theme with settings.php, scss, amd modules

To deploy custom themes, mount them as volumes in the docker-compose configuration.

## Important Considerations

1. **Default Credentials**: Change default passwords before production use
2. **HTTPS Configuration**: SSL certificates needed for production HTTPS
3. **Email Configuration**: SMTP settings required for email functionality (commented in moodle.env)
4. **Performance Tuning**: PHP memory limits and opcache settings adjustable based on load
5. **Redis Configuration**: For high-concurrency, configure Moodle cache stores via admin UI
6. **Backup Strategy**: Regular database backups using provided commands
7. **Container Registries**: Multiple registries available (Docker Hub, GHCR, Quay, AWS ECR) - test with `./test-registries.sh`