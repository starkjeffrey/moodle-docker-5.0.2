# Redis High-Concurrency Configuration for Moodle

This setup adds Redis caching to Moodle for handling high concurrent user loads efficiently.

## Key Features

### Performance Optimizations
- **10,000 max clients**: Configured for high concurrent connections
- **Session handling**: Redis manages PHP sessions for better performance
- **Multiple cache stores**: Separate Redis DBs for different cache types
- **AOF persistence**: Append-only file for data durability
- **LRU eviction**: Automatic memory management when limits reached

### High-Concurrency Benefits
1. **Reduced Database Load**: Caches frequently accessed data
2. **Faster Session Management**: Redis handles sessions instead of files/DB
3. **Improved Page Load Times**: Application cache reduces computation
4. **Better Scalability**: Can handle thousands of concurrent users
5. **Lower Latency**: In-memory operations vs disk I/O

## Quick Start for Live Testing

### 1. Create Required Directories
```bash
mkdir -p volumes/redis volumes/mariadb volumes/moodle volumes/moodledata
chmod 755 volumes/*
```

### 2. Start Services
```bash
# Using the hardened configuration with Redis
docker-compose -f docker-compose.moodle-hardened.yml up -d

# Check service health
docker-compose -f docker-compose.moodle-hardened.yml ps
```

### 3. Verify Redis Connection
```bash
# Test Redis connectivity
docker exec moodle-redis redis-cli --pass redis_password_change_me ping
# Should return: PONG

# Check Redis info
docker exec moodle-redis redis-cli --pass redis_password_change_me INFO clients
```

### 4. Monitor Redis Performance
```bash
# Real-time monitoring
docker exec -it moodle-redis redis-cli --pass redis_password_change_me monitor

# Check connection count
docker exec moodle-redis redis-cli --pass redis_password_change_me CLIENT LIST | wc -l

# Memory usage
docker exec moodle-redis redis-cli --pass redis_password_change_me INFO memory
```

## Moodle Cache Configuration

After Moodle starts, configure cache stores via Admin UI:

1. Login as admin (admin/Admin@123456)
2. Go to: Site administration → Plugins → Caching → Configuration
3. Add Redis cache instances:

### Application Cache
- Store name: `Redis Application`
- Server: `redis:6379`
- Password: `redis_password_change_me`
- Database: 0
- Key prefix: `mdl_app_`

### Session Cache
- Store name: `Redis Session`
- Server: `redis:6379`
- Password: `redis_password_change_me`
- Database: 1
- Key prefix: `mdl_sess_`

### Request Cache
- Store name: `Redis Request`
- Server: `redis:6379`
- Password: `redis_password_change_me`
- Database: 2
- Key prefix: `mdl_req_`

## Load Testing

### Using Apache Bench
```bash
# Test 1000 requests with 100 concurrent connections
ab -n 1000 -c 100 http://localhost:8080/

# Test with authentication
ab -n 1000 -c 100 -C "MoodleSession=your_session_id" http://localhost:8080/my/
```

### Using JMeter for Complex Scenarios
1. Create test plan with:
   - User login flow
   - Course access patterns
   - Quiz submissions
   - File uploads

### Monitor During Testing
```bash
# Watch Redis connections
watch -n 1 'docker exec moodle-redis redis-cli --pass redis_password_change_me CLIENT LIST | wc -l'

# Monitor Redis stats
docker exec moodle-redis redis-cli --pass redis_password_change_me --stat

# Check Moodle logs
docker logs -f moodle-app

# System resources
docker stats
```

## Performance Metrics to Track

### Redis Metrics
- Connected clients: Target < 5000 for stability
- Used memory: Should stay under 1GB limit
- Evicted keys: Should be minimal
- Keyspace hits/misses ratio: Aim for >90% hit rate
- Commands/sec: Monitor during peak load

### Moodle Metrics
- Page load time: Should improve 30-50% with Redis
- Concurrent users: Can handle 500-1000+ concurrent users
- Database queries: Should reduce by 40-60%
- Session handling: Near instant with Redis

## Troubleshooting

### Redis Connection Issues
```bash
# Check Redis logs
docker logs moodle-redis

# Test connection from Moodle container
docker exec moodle-app redis-cli -h redis -p 6379 --pass redis_password_change_me ping
```

### High Memory Usage
```bash
# Check memory info
docker exec moodle-redis redis-cli --pass redis_password_change_me INFO memory

# Force cleanup
docker exec moodle-redis redis-cli --pass redis_password_change_me MEMORY PURGE

# Adjust maxmemory if needed
docker exec moodle-redis redis-cli --pass redis_password_change_me CONFIG SET maxmemory 2gb
```

### Performance Tuning
```bash
# Increase max clients if hitting limits
docker exec moodle-redis redis-cli --pass redis_password_change_me CONFIG SET maxclients 20000

# Adjust TCP backlog for high connection rate
docker exec moodle-redis redis-cli --pass redis_password_change_me CONFIG SET tcp-backlog 1024

# Save configuration
docker exec moodle-redis redis-cli --pass redis_password_change_me CONFIG REWRITE
```

## Production Recommendations

1. **Change default passwords** in all .env files
2. **Use Redis Sentinel** for high availability
3. **Enable SSL/TLS** for Redis connections
4. **Set up monitoring** with Prometheus/Grafana
5. **Configure backups** for Redis AOF files
6. **Use dedicated Redis server** for large deployments
7. **Consider Redis Cluster** for horizontal scaling

## Benchmarking Results (Expected)

With Redis enabled, you should see:
- **Login time**: 200-300ms (vs 500-800ms without Redis)
- **Course page load**: 150-250ms (vs 400-600ms)
- **Dashboard load**: 100-200ms (vs 300-500ms)
- **Concurrent capacity**: 500-1000 users (vs 100-200 without Redis)

## Security Notes

- Redis password is set (not using empty password)
- FLUSHDB and FLUSHALL commands are disabled
- Redis only exposed internally (not to host)
- AOF persistence enabled for data recovery
- Protected mode enabled
- Security capabilities properly configured in Docker