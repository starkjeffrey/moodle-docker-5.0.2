# PUCSR API Plugin Deployment Guide

## Pre-Deployment Checklist

### Environment Requirements

- [ ] **Moodle Version**: 4.4+ (LTS) confirmed
- [ ] **PHP Version**: 8.1+ confirmed
- [ ] **Database**: MySQL 8.0+ or PostgreSQL 13+ confirmed
- [ ] **Web Server**: Apache 2.4+ or Nginx 1.18+ confirmed
- [ ] **SSL Certificate**: Valid HTTPS certificate installed
- [ ] **Memory Limit**: PHP memory_limit ≥ 512M
- [ ] **Execution Time**: max_execution_time ≥ 300 seconds

### System Preparation

- [ ] **Backup Database**: Full Moodle database backup created
- [ ] **Backup Files**: Full Moodle file system backup created
- [ ] **Test Environment**: Plugin tested in staging environment
- [ ] **Maintenance Mode**: Maintenance mode scheduled if needed
- [ ] **Resource Planning**: Peak usage times identified for deployment

### SIS System Preparation

- [ ] **SIS API**: API endpoint URLs confirmed and accessible
- [ ] **Authentication**: API keys/tokens generated and tested
- [ ] **Rate Limits**: API rate limits confirmed and documented
- [ ] **Data Mapping**: User/course ID mapping strategy defined
- [ ] **Test Data**: Sample test data prepared for validation

## Deployment Steps

### Step 1: Plugin Installation

```bash
# 1. Navigate to Moodle root directory
cd /path/to/moodle

# 2. Create plugin directory
mkdir -p local/pucsr_api

# 3. Copy plugin files (choose one method)

# Method A: Direct copy
cp -r /path/to/plugin/files/* local/pucsr_api/

# Method B: Git clone (recommended)
git clone <repository-url> local/pucsr_api

# Method C: Download and extract
wget <plugin-zip-url> -O pucsr_api.zip
unzip pucsr_api.zip -d local/
mv local/pucsr_api-main local/pucsr_api

# 4. Set proper permissions
chown -R www-data:www-data local/pucsr_api
chmod -R 755 local/pucsr_api
```

### Step 2: Database Installation

```bash
# 1. Run Moodle upgrade to install database tables
php admin/cli/upgrade.php --non-interactive

# 2. Verify tables were created
mysql -u moodle_user -p moodle_db -e "SHOW TABLES LIKE 'mdl_local_pucsr_api_%';"

# Expected output:
# mdl_local_pucsr_api_sync_log
# mdl_local_pucsr_api_sis_mapping
# mdl_local_pucsr_api_composite_config
```

### Step 3: Web Services Configuration

#### 3.1 Enable Web Services
```bash
# Via CLI
php admin/cli/cfg.php --name=enablewebservices --set=1

# Or via web interface:
# Site Administration → Advanced features → Enable web services ✓
```

#### 3.2 Enable REST Protocol
```bash
# Via CLI
php admin/cli/cfg.php --name=webserviceprotocols --set=rest

# Or via web interface:
# Site Administration → Plugins → Web services → Manage protocols
# Enable: REST protocol ✓
```

#### 3.3 Create External Service

**Via Web Interface:**

1. Navigate to: **Site Administration → Plugins → Web services → External services**
2. Click **Add** to create new service
3. Configure service:
   ```
   Name: PUCSR API Service
   Short name: pucsr_api_service
   Enabled: ✓
   Authorised users only: ✓
   Can download files: ✗
   Can upload files: ✗
   ```

4. **Add Functions** to the service:
   - `local_pucsr_api_create_composite_structure`
   - `local_pucsr_api_get_composite_grades`
   - `local_pucsr_api_update_composite_grades`
   - `local_pucsr_api_sync_sis_data`
   - `local_pucsr_api_push_grades_to_sis`
   - `local_pucsr_api_pull_enrollments_from_sis`
   - `local_pucsr_api_get_course_analytics`
   - `local_pucsr_api_get_sync_logs`

#### 3.4 Create Service User and Token

1. **Create API User**:
   - Navigate to: **Site Administration → Users → Accounts → Add a new user**
   - Configure user:
     ```
     Username: pucsr_api_user
     Password: [strong password]
     First name: PUCSR
     Last name: API User
     Email: api@pucsr.edu.kh
     ```

2. **Assign Capabilities**:
   - Navigate to: **Site Administration → Users → Permissions → Assign system roles**
   - Create role "API User" with capabilities:
     ```
     local/pucsr_api:sync_sis
     local/pucsr_api:push_grades
     local/pucsr_api:pull_enrollments
     local/pucsr_api:manage_composite
     local/pucsr_api:view_analytics
     moodle/grade:manage
     moodle/grade:view
     moodle/grade:edit
     ```

3. **Create Token**:
   - Navigate to: **Site Administration → Plugins → Web services → Manage tokens**
   - Create token:
     ```
     User: pucsr_api_user
     Service: PUCSR API Service
     Valid until: [appropriate date]
     IP restriction: [your SIS server IPs]
     ```
   - **Save the token securely!**

### Step 4: Plugin Configuration

Navigate to: **Site Administration → Plugins → Local plugins → PUCSR API**

#### 4.1 SIS Integration Settings
```
SIS Integration: ✓ Enabled
SIS API URL: https://sis.pucsr.edu.kh/api
SIS API Key: [your-secret-api-key]
SIS Timeout: 30
```

#### 4.2 Synchronization Settings
```
Auto-push grades: ✓ (optional)
Auto-pull enrollments: ✓ (optional)
Default sync interval: 30
```

#### 4.3 Composite Grades Settings
```
Enable composite grades: ✓
Default grammar weight: 0.5
Default writing weight: 0.5
```

#### 4.4 API Configuration
```
API Rate Limit: 100
Debug Mode: ✗ (enable only for troubleshooting)
```

### Step 5: Test Configuration

```bash
# 1. Test plugin configuration
php local/pucsr_api/cli/sync_sis.php --config-check

# Expected output: All configuration items should show [OK]

# 2. Test SIS connectivity (dry run)
php local/pucsr_api/cli/sync_sis.php --dry-run --verbose

# 3. Test composite structure creation
php local/pucsr_api/cli/create_composite_structure.php --list-courses

# 4. Test web service token
curl -X POST "https://your-moodle.site/webservice/rest/server.php" \
  -d "wstoken=YOUR_TOKEN&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
```

### Step 6: Initial Data Setup

#### 6.1 Create SIS Mappings (if needed)
```sql
-- Example: Map existing users to SIS IDs
INSERT INTO mdl_local_pucsr_api_sis_mapping
(entity_type, moodle_id, sis_id, sis_code, active, timecreated, timemodified)
VALUES
('user', 123, 'SIS_USER_456', 'USER456', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());

-- Example: Map courses to SIS codes
INSERT INTO mdl_local_pucsr_api_sis_mapping
(entity_type, moodle_id, sis_id, sis_code, active, timecreated, timemodified)
VALUES
('course', 456, 'SIS_COURSE_789', 'IEAP4-2025-SPRING', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP());
```

#### 6.2 Create Test Composite Structure
```bash
# Create IEAP-4 structure for test course
php local/pucsr_api/cli/create_composite_structure.php \
  --courseid=123 \
  --structure=ieap4 \
  --verbose
```

### Step 7: Automation Setup

#### 7.1 Cron Jobs
Add to server crontab (`crontab -e`):

```bash
# PUCSR API Synchronization Jobs

# Sync all data every 30 minutes
*/30 * * * * /usr/bin/php /path/to/moodle/local/pucsr_api/cli/sync_sis.php --mode=both --type=all 2>&1 | logger -t pucsr_api

# Pull enrollments daily at 6 AM
0 6 * * * /usr/bin/php /path/to/moodle/local/pucsr_api/cli/sync_sis.php --mode=pull --type=enrollments 2>&1 | logger -t pucsr_api

# Push grades every 2 hours during business hours (8 AM - 6 PM)
0 8-18/2 * * * /usr/bin/php /path/to/moodle/local/pucsr_api/cli/sync_sis.php --mode=push --type=grades 2>&1 | logger -t pucsr_api
```

#### 7.2 Log Rotation
Create `/etc/logrotate.d/pucsr_api`:

```
/var/log/pucsr_api.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 www-data www-data
}
```

### Step 8: Monitoring Setup

#### 8.1 Log Monitoring Script
Create `/usr/local/bin/check_pucsr_sync.sh`:

```bash
#!/bin/bash

# Check for failed syncs in last hour
FAILED_SYNCS=$(mysql -u moodle_user -p'password' moodle_db -N -e "
SELECT COUNT(*) FROM mdl_local_pucsr_api_sync_log
WHERE status IN ('failed', 'partial')
AND timecreated > UNIX_TIMESTAMP() - 3600
")

if [ "$FAILED_SYNCS" -gt 0 ]; then
    echo "WARNING: $FAILED_SYNCS failed sync(s) in the last hour"
    # Send alert email
    echo "PUCSR API sync failures detected. Check logs immediately." | \
    mail -s "PUCSR API Alert" admin@pucsr.edu.kh
fi
```

#### 8.2 Health Check Endpoint
Add to web server configuration:

```nginx
# Nginx example
location /health/pucsr-api {
    access_log off;
    add_header Content-Type text/plain;
    return 200 "PUCSR API OK";
}
```

### Step 9: Security Hardening

#### 9.1 File Permissions
```bash
# Secure sensitive files
chmod 600 config.php
chmod 600 local/pucsr_api/settings.php

# Ensure web server ownership
chown -R www-data:www-data /path/to/moodle
```

#### 9.2 Network Security
```bash
# Firewall rules (example for UFW)
ufw allow from SIS_SERVER_IP to any port 443
ufw allow from SIS_SERVER_IP to any port 80

# Rate limiting (example for Nginx)
# Add to nginx.conf:
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;
location /webservice/ {
    limit_req zone=api burst=5;
}
```

#### 9.3 Database Security
```sql
-- Create dedicated database user for API operations
CREATE USER 'pucsr_api'@'localhost' IDENTIFIED BY 'strong_password';

-- Grant minimal required permissions
GRANT SELECT, INSERT, UPDATE ON moodle.mdl_local_pucsr_api_* TO 'pucsr_api'@'localhost';
GRANT SELECT ON moodle.mdl_user TO 'pucsr_api'@'localhost';
GRANT SELECT ON moodle.mdl_course TO 'pucsr_api'@'localhost';
GRANT SELECT, INSERT, UPDATE ON moodle.mdl_grade_* TO 'pucsr_api'@'localhost';

FLUSH PRIVILEGES;
```

## Post-Deployment Validation

### Functional Tests

- [ ] **Plugin Installation**: Plugin appears in installed plugins list
- [ ] **Web Services**: All API functions available and callable
- [ ] **Database**: All tables created with correct structure
- [ ] **Configuration**: All settings save and load correctly
- [ ] **Permissions**: User roles and capabilities working correctly

### Integration Tests

- [ ] **SIS Connectivity**: Successful connection to SIS API
- [ ] **Grade Creation**: Composite structures create correctly
- [ ] **Grade Retrieval**: Grade data retrieves with proper format
- [ ] **Grade Updates**: Grade modifications save and sync properly
- [ ] **User Sync**: User data pulls from SIS correctly
- [ ] **Enrollment Sync**: Enrollment data pulls from SIS correctly

### Performance Tests

- [ ] **API Response Time**: <2 seconds for typical requests
- [ ] **Bulk Operations**: Large sync operations complete successfully
- [ ] **Concurrent Users**: Multiple simultaneous API calls handled
- [ ] **Resource Usage**: Memory and CPU usage within acceptable limits

### Security Tests

- [ ] **Authentication**: Invalid tokens properly rejected
- [ ] **Authorization**: Users cannot access unauthorized functions
- [ ] **Input Validation**: Invalid data properly validated and rejected
- [ ] **SQL Injection**: No SQL injection vulnerabilities
- [ ] **XSS Prevention**: No cross-site scripting vulnerabilities

## Production Checklist

### Before Go-Live

- [ ] **Backup Verification**: Confirm backups are complete and restorable
- [ ] **Rollback Plan**: Document rollback procedures
- [ ] **Support Contacts**: Emergency contact information available
- [ ] **Documentation**: All documentation updated and accessible
- [ ] **Training**: Staff trained on new functionality

### Go-Live Activities

- [ ] **Maintenance Window**: Schedule announced to users
- [ ] **Status Page**: Update system status page
- [ ] **Monitoring**: Enable enhanced monitoring during deployment
- [ ] **Support Team**: Support team on standby
- [ ] **Communication**: Go-live announcement prepared

### Post Go-Live

- [ ] **Initial Sync**: Run initial full synchronization
- [ ] **Validation**: Verify all systems functioning correctly
- [ ] **Performance**: Monitor system performance metrics
- [ ] **Error Monitoring**: Check for any error logs or failed operations
- [ ] **User Feedback**: Collect and address initial user feedback

## Rollback Procedures

### Emergency Rollback

If critical issues occur:

```bash
# 1. Enable maintenance mode
php admin/cli/maintenance.php --enable

# 2. Disable web services
php admin/cli/cfg.php --name=enablewebservices --set=0

# 3. Remove plugin files
rm -rf local/pucsr_api

# 4. Restore database backup
mysql -u root -p moodle_db < moodle_backup_pre_deployment.sql

# 5. Clear caches
php admin/cli/purge_caches.php

# 6. Disable maintenance mode
php admin/cli/maintenance.php --disable
```

### Gradual Rollback

For non-critical issues:

```bash
# 1. Disable SIS integration
php admin/cli/cfg.php --component=local_pucsr_api --name=sis_enabled --set=0

# 2. Disable cron jobs
# Comment out PUCSR API cron jobs in crontab

# 3. Monitor and fix issues
# Address specific problems while keeping plugin installed
```

## Support and Maintenance

### Regular Maintenance Tasks

#### Daily
- [ ] Check sync logs for errors
- [ ] Verify API connectivity
- [ ] Monitor system performance

#### Weekly
- [ ] Review error patterns
- [ ] Update documentation if needed
- [ ] Check backup systems

#### Monthly
- [ ] Review security logs
- [ ] Update API keys if required
- [ ] Performance optimization review

### Support Contacts

| Role | Contact | Phone | Email |
|------|---------|-------|-------|
| System Administrator | [Name] | [Phone] | [Email] |
| Database Administrator | [Name] | [Phone] | [Email] |
| SIS System Contact | [Name] | [Phone] | [Email] |
| Moodle Administrator | [Name] | [Phone] | [Email] |

### Emergency Procedures

1. **Critical System Down**:
   - Enable maintenance mode
   - Contact system administrator
   - Activate rollback procedures if needed

2. **Data Sync Issues**:
   - Stop automated sync jobs
   - Investigate sync logs
   - Contact SIS team if needed

3. **Security Incident**:
   - Disable affected services
   - Revoke API tokens
   - Contact security team

---

*PUCSR API Plugin Deployment Guide - Version 1.0*