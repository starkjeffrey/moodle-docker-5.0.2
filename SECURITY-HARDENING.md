# Docker Compose Security Hardening Guide for Moodle

## Security Issues Found & Fixes Applied

### 1. **Database Port Exposure** 🔴 CRITICAL
**Issue**: MariaDB port 3306 exposed to all interfaces
**Fix**: Remove external port mapping, use internal network only
```yaml
# Before (INSECURE):
ports:
  - "3306:3306"

# After (SECURE):
expose:
  - "3306"  # Only internal network access
```

### 2. **Weak Passwords** 🔴 CRITICAL
**Issue**: Simple passwords in environment files
**Fix**: Use strong, complex passwords
- Created `mariadb-secure.env` and `moodle-secure.env` with strong passwords
- Passwords should be at least 20 characters with mixed case, numbers, and symbols

### 3. **Direct Web Port Exposure** 🟡 IMPORTANT
**Issue**: Moodle directly exposed on ports 80/443
**Fix**: Bind to localhost only, use reverse proxy
```yaml
# Before:
ports:
  - "80:8080"
  - "443:8443"

# After:
ports:
  - "127.0.0.1:8080:8080"  # Localhost only
  - "127.0.0.1:8443:8443"
```

### 4. **Missing Security Capabilities** 🟡 IMPORTANT
**Fix Applied**: Added security options to containers:
```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:  # Only required capabilities
  - CHOWN
  - SETGID
  - SETUID
  - NET_BIND_SERVICE
```

### 5. **No Resource Limits** 🟡 IMPORTANT
**Fix Applied**: Added resource constraints:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 4G
    reservations:
      cpus: '1'
      memory: 1G
```

### 6. **Missing Network Isolation** 🟢 RECOMMENDED
**Fix Applied**: Configured isolated network with specific subnet:
```yaml
networks:
  moodle-network:
    ipam:
      config:
        - subnet: 172.20.0.0/24
```

### 7. **Volume Security** 🟢 RECOMMENDED
**Fix Applied**: Use bind mounts with proper permissions instead of Docker volumes

## Additional Security Measures

### A. Nginx Reverse Proxy Configuration
Created `nginx-reverse-proxy.conf` with:
- SSL/TLS termination
- Rate limiting
- Security headers (HSTS, CSP, X-Frame-Options)
- DDoS protection
- Hide sensitive files

### B. PHP Hardening in Environment
Added to `moodle-secure.env`:
- `PHP_EXPOSE_PHP=Off`
- `PHP_DISPLAY_ERRORS=Off`
- Session cookie security settings
- Error logging configuration

### C. File System Security
Added tmpfs mounts for temporary directories:
```yaml
tmpfs:
  - /tmp
  - /var/run
  - /var/cache
```

## Implementation Steps

1. **Stop current containers**:
   ```bash
   docker compose -f docker-compose.moodle.yml down
   ```

2. **Create volume directories**:
   ```bash
   mkdir -p volumes/{mariadb,moodle,moodledata}
   chmod 755 volumes/
   ```

3. **Update environment files**:
   ```bash
   cp .envs/.mariadb/mariadb-secure.env .envs/.mariadb/mariadb.env
   cp .envs/.moodle/moodle-secure.env .envs/.moodle/moodle.env
   ```

4. **Start with hardened configuration**:
   ```bash
   docker compose -f docker-compose.moodle-hardened.yml up -d
   ```

5. **Install and configure Nginx** (on Ubuntu server):
   ```bash
   apt-get install nginx certbot python3-certbot-nginx
   cp nginx-reverse-proxy.conf /etc/nginx/sites-available/moodle
   ln -s /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
   certbot --nginx -d moodle.yourdomain.com
   nginx -t && systemctl reload nginx
   ```

## Security Checklist

- [ ] Strong passwords (20+ chars) for all services
- [ ] Database not exposed externally
- [ ] Web services behind reverse proxy
- [ ] SSL/TLS certificates installed
- [ ] Rate limiting configured
- [ ] Security headers enabled
- [ ] Resource limits set
- [ ] Container capabilities minimized
- [ ] Network isolation configured
- [ ] Regular security updates scheduled
- [ ] Backup strategy in place
- [ ] Log monitoring configured
- [ ] Firewall rules configured

## Monitoring Commands

```bash
# Check container security
docker inspect moodle-app | grep -A5 SecurityOpt

# Monitor resource usage
docker stats

# Check logs for attacks
docker logs moodle-app | grep -i "attack\|exploit\|injection"

# Network connections
docker exec moodle-app netstat -tulpn

# File integrity
docker exec moodle-app find /bitnami/moodle -type f -perm /4000
```

## Regular Maintenance

1. **Weekly**: Review logs for suspicious activity
2. **Monthly**: Update Docker images
3. **Quarterly**: Security audit and password rotation
4. **Annually**: Penetration testing

## Emergency Response

If compromised:
1. `docker compose -f docker-compose.moodle-hardened.yml down`
2. Backup data volumes
3. Review logs for breach timeline
4. Reset all passwords
5. Rebuild from clean images
6. Restore data from clean backup