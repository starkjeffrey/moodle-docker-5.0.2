# PUCSR API Plugin for Moodle

A comprehensive API plugin designed for PUCSR (Preah Kossomak University of Cambodia, School of Research) to enhance Moodle with Student Information System (SIS) integration and composite grade management capabilities.

## Features

### 🎯 Composite Grade Management
- **Complete IEAP Support**: All IEAP levels (1-6) with pre-configured structures
- **Auto-Detection**: Automatically detect IEAP level from course names
- **Flexible Components**: Grammar, Writing, Speaking, Listening, Reading support
- **Custom Structures**: Flexible grade category creation with weighted components
- **Automated Calculation**: Weighted grade calculations with real-time updates
- **Grade API**: RESTful endpoints for grade creation, retrieval, and updates

### 🔄 SIS Integration
- **Bidirectional Sync**: Push grades to SIS, pull enrollments and users
- **Real-time Updates**: Automated synchronization with configurable intervals
- **Error Handling**: Comprehensive logging and error recovery
- **Batch Operations**: Efficient bulk processing of large datasets

### 🛠️ Automation & CLI Tools
- **Sync Scripts**: Command-line tools for automated SIS synchronization
- **Structure Creation**: CLI utility for creating grade structures
- **Monitoring**: Sync logging and status reporting
- **Cron Integration**: Scheduled automatic operations

### 🧪 Testing & Quality
- **Unit Tests**: Comprehensive PHPUnit test coverage
- **Integration Tests**: End-to-end API testing
- **Data Validation**: Input validation and error handling
- **Performance Testing**: Load testing for large datasets

## Installation

### 1. Plugin Installation

```bash
# Navigate to Moodle root directory
cd /path/to/moodle

# Copy plugin to local plugins directory
cp -r /path/to/pucsr_api local/

# Or clone from repository
git clone <repository-url> local/pucsr_api
```

### 2. Database Installation

```bash
# Run Moodle upgrade to install database tables
php admin/cli/upgrade.php --non-interactive
```

### 3. Web Service Configuration

1. **Enable Web Services**:
   - Site Administration → Advanced features → Enable web services ✓

2. **Enable REST Protocol**:
   - Site Administration → Plugins → Web services → Manage protocols
   - Enable REST protocol

3. **Create Service**:
   - Site Administration → Plugins → Web services → External services
   - Add service: "PUCSR API Service"
   - Add functions: All `local_pucsr_api_*` functions

4. **Create Token**:
   - Site Administration → Plugins → Web services → Manage tokens
   - Create token for PUCSR API Service

### 4. Plugin Configuration

Navigate to: **Site Administration → Plugins → Local plugins → PUCSR API**

#### SIS Integration Settings
```
SIS API URL: https://your-sis-system.com/api
SIS API Key: your-secret-api-key
API Timeout: 30 seconds
Enable SIS Integration: ✓
```

#### Synchronization Settings
```
Auto-push grades: ✓ (optional)
Auto-pull enrollments: ✓ (optional)
Default sync interval: 30 minutes
```

#### Composite Grades Settings
```
Enable composite grades: ✓
Default grammar weight: 0.5
Default writing weight: 0.5
```

## Usage

### Creating IEAP Grade Structures

#### Method 1: Auto-Detection (Recommended)

```bash
# Auto-detect IEAP level from course name
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_create_composite_structure",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "auto_detect": true
  }'

# Or use the dedicated IEAP function
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_create_ieap_structure",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "ieap_level": "ieap4"
  }'
```

#### Method 2: Specific IEAP Level

```bash
# Create IEAP-1 (Beginner) structure
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_create_ieap_structure",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "ieap_level": "ieap1"
  }'

# Create IEAP-6 (Advanced) structure with customizations
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_create_ieap_structure",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "ieap_level": "ieap6",
    "customizations": {
      "writing_weight": 0.5,
      "speaking_weight": 0.25
    }
  }'
```

#### Method 3: CLI Script

```bash
# Auto-detect IEAP level
php local/pucsr_api/cli/create_composite_structure.php \
  --courseid=123 \
  --structure=auto

# Create specific IEAP level
php local/pucsr_api/cli/create_composite_structure.php \
  --courseid=123 \
  --structure=ieap6

# Create custom structure from JSON file
php local/pucsr_api/cli/create_composite_structure.php \
  --courseid=123 \
  --structure=custom \
  --config-file=custom_structure.json

# List available courses
php local/pucsr_api/cli/create_composite_structure.php --list-courses
```

### SIS Synchronization

#### Method 1: Web Service API

```bash
# Sync all data (users, enrollments, grades)
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_sync_sis_data",
    "moodlewsrestformat": "json",
    "sync_type": "all",
    "direction": "both"
  }'

# Push grades for specific course
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_push_grades_to_sis",
    "moodlewsrestformat": "json",
    "courseid": 123
  }'
```

#### Method 2: CLI Script

```bash
# Full bidirectional sync
php local/pucsr_api/cli/sync_sis.php \
  --mode=both \
  --type=all \
  --verbose

# Push grades for specific course
php local/pucsr_api/cli/sync_sis.php \
  --mode=push \
  --type=grades \
  --courseid=123

# Pull enrollments for specific term
php local/pucsr_api/cli/sync_sis.php \
  --mode=pull \
  --type=enrollments \
  --term="2025-Spring"

# Dry run to see what would happen
php local/pucsr_api/cli/sync_sis.php \
  --dry-run \
  --verbose
```

#### Method 3: Cron Automation

Add to server crontab:

```bash
# Sync every 30 minutes
*/30 * * * * /usr/bin/php /path/to/moodle/local/pucsr_api/cli/sync_sis.php --mode=both --type=all

# Push grades every hour
0 * * * * /usr/bin/php /path/to/moodle/local/pucsr_api/cli/sync_sis.php --mode=push --type=grades --courseid=123

# Pull enrollments daily at 6 AM
0 6 * * * /usr/bin/php /path/to/moodle/local/pucsr_api/cli/sync_sis.php --mode=pull --type=enrollments
```

### Retrieving Grades

```bash
# Get composite grades for a course
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_get_composite_grades",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "include_breakdown": true
  }'
```

### Updating Grades

```bash
# Update grades for specific items
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your-token",
    "wsfunction": "local_pucsr_api_update_composite_grades",
    "moodlewsrestformat": "json",
    "updates": [
      {
        "courseid": 123,
        "userid": 456,
        "itemid": 789,
        "grade": 85.5
      }
    ]
  }'
```

## API Reference

### Authentication

All API calls require a valid web service token:

```
Authorization: Bearer YOUR_TOKEN
```

Or as a parameter:

```
wstoken=YOUR_TOKEN
```

### Endpoints

| Function | Purpose | Method |
|----------|---------|---------|
| `local_pucsr_api_create_composite_structure` | Create IEAP-4 style grade structure | POST |
| `local_pucsr_api_get_composite_grades` | Retrieve student grades with breakdown | GET |
| `local_pucsr_api_update_composite_grades` | Update grades in composite structure | POST |
| `local_pucsr_api_sync_sis_data` | Synchronize data with SIS system | POST |
| `local_pucsr_api_push_grades_to_sis` | Push grades to SIS | POST |
| `local_pucsr_api_pull_enrollments_from_sis` | Pull enrollments from SIS | POST |
| `local_pucsr_api_get_course_analytics` | Get course analytics and reports | GET |
| `local_pucsr_api_get_sync_logs` | Retrieve synchronization logs | GET |

### Response Format

All responses follow this structure:

```json
{
  "success": true|false,
  "data": { ... },
  "error": "Error message if failed",
  "timestamp": 1642678800
}
```

## IEAP Course Structures

The plugin supports all IEAP levels with pre-configured grade structures:

### IEAP-1 (Beginner)
- **Grammar & Vocabulary** (40%): Basic grammar quizzes, vocabulary tests, final exam
- **Speaking & Listening** (35%): Pronunciation practice, basic conversation, listening comprehension, speaking assessment
- **Basic Writing** (25%): Sentence writing, paragraph writing, basic essay

### IEAP-2 (Elementary)
- **Grammar & Vocabulary** (35%): Grammar quizzes, vocabulary tests, midterm/final exams
- **Speaking & Listening** (35%): Pronunciation assessment, dialogue practice, listening tests, oral presentation
- **Writing** (30%): Paragraph writing, short essays

### IEAP-3 (Pre-Intermediate)
- **Grammar** (30%): Grammar quizzes, midterm/final exams
- **Writing** (35%): Descriptive essays, narrative essays, research project
- **Speaking** (20%): Individual presentation, group discussion, speaking exam
- **Reading & Listening** (15%): Reading comprehension, listening tests

### IEAP-4 (Intermediate)
- **Grammar** (50%): Grammar quizzes, midterm/final exams
- **Writing** (50%): Essays, portfolio

### IEAP-5 (Upper-Intermediate)
- **Academic Writing** (40%): Argumentative essay, research paper, critical analysis, portfolio
- **Grammar & Language Use** (25%): Advanced grammar tests, language use final
- **Speaking & Presentation** (25%): Academic presentation, debate, speaking proficiency test
- **Reading & Critical Thinking** (10%): Critical reading test, text analysis project

### IEAP-6 (Advanced)
- **Academic Writing & Research** (45%): Research proposal, literature review, research paper drafts, final paper, portfolio
- **Advanced Language Skills** (25%): Advanced grammar & style, academic vocabulary, language proficiency exam
- **Presentation & Communication** (20%): Research presentation, academic conference simulation, professional communication
- **Critical Analysis** (10%): Critical reading analysis, media analysis project

## Custom Structure Configuration

For non-IEAP courses, create a JSON file with your custom grade structure:

```json
{
  "name": "Advanced English Assessment",
  "components": [
    {
      "name": "Grammar & Vocabulary",
      "weight": 0.3,
      "subitems": [
        {"name": "Grammar Quiz 1", "maxgrade": 50, "itemtype": "manual"},
        {"name": "Grammar Quiz 2", "maxgrade": 50, "itemtype": "manual"},
        {"name": "Vocabulary Test", "maxgrade": 100, "itemtype": "manual"}
      ]
    },
    {
      "name": "Writing Skills",
      "weight": 0.4,
      "subitems": [
        {"name": "Essay 1: Descriptive", "maxgrade": 100, "itemtype": "manual"},
        {"name": "Essay 2: Argumentative", "maxgrade": 100, "itemtype": "manual"},
        {"name": "Research Paper", "maxgrade": 150, "itemtype": "manual"}
      ]
    },
    {
      "name": "Speaking & Listening",
      "weight": 0.3,
      "subitems": [
        {"name": "Oral Presentation", "maxgrade": 100, "itemtype": "manual"},
        {"name": "Listening Comprehension", "maxgrade": 80, "itemtype": "manual"},
        {"name": "Conversation Assessment", "maxgrade": 70, "itemtype": "manual"}
      ]
    }
  ]
}
```

## Testing

### Run Unit Tests

```bash
# Run all PUCSR API tests
php admin/tool/phpunit/cli/util.php --buildcomponentconfigs
php vendor/bin/phpunit local/pucsr_api/tests/phpunit/

# Run specific test class
php vendor/bin/phpunit local/pucsr_api/tests/phpunit/composite_grades_test.php

# Run with coverage
php vendor/bin/phpunit --coverage-html coverage/ local/pucsr_api/tests/phpunit/
```

### Test Configuration

```bash
# Check plugin configuration
php local/pucsr_api/cli/sync_sis.php --config-check

# Test SIS connectivity
php local/pucsr_api/cli/sync_sis.php --dry-run --verbose
```

## Troubleshooting

### Common Issues

1. **SIS Connection Failed**
   ```bash
   # Check configuration
   php local/pucsr_api/cli/sync_sis.php --config-check

   # Test API connectivity
   curl -H "Authorization: Bearer YOUR_API_KEY" https://your-sis-api.com/api/status
   ```

2. **Grades Not Calculating**
   ```bash
   # Force grade recalculation
   php admin/cli/run_jobs.php --cronoverride

   # Check grade calculation settings
   php local/pucsr_api/cli/create_composite_structure.php --list-courses
   ```

3. **Web Service Errors**
   ```bash
   # Check web service status
   php admin/cli/external_functions.php --list | grep pucsr_api

   # Verify token permissions
   curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
     -d "wstoken=YOUR_TOKEN&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
   ```

4. **Database Issues**
   ```bash
   # Check plugin tables
   php admin/cli/upgrade.php --non-interactive

   # Verify table structure
   mysql -e "DESCRIBE mdl_local_pucsr_api_sync_log;" your_moodle_db
   ```

### Debug Mode

Enable debug mode for detailed logging:

```php
// In config.php
$CFG->debug = E_ALL;
$CFG->debugdisplay = true;

// Or via admin settings
set_config('debug_mode', 1, 'local_pucsr_api');
```

### Log Locations

- **Moodle Logs**: `/path/to/moodledata/logs/`
- **Web Server Logs**: `/var/log/apache2/error.log` or `/var/log/nginx/error.log`
- **SIS Sync Logs**: Database table `mdl_local_pucsr_api_sync_log`

## Security Considerations

1. **API Keys**: Store SIS API keys securely, rotate regularly
2. **Tokens**: Use restricted tokens with minimal required capabilities
3. **HTTPS**: Always use HTTPS for API communications
4. **Rate Limiting**: Implement rate limiting for API endpoints
5. **Input Validation**: All inputs are validated and sanitized
6. **Audit Logging**: All operations are logged for audit trails

## Performance Optimization

1. **Batch Operations**: Use bulk sync for large datasets
2. **Caching**: Enable Moodle caching for improved performance
3. **Database Indexes**: Ensure proper indexing on custom tables
4. **Resource Limits**: Configure appropriate PHP memory and execution limits

```php
// In config.php for better performance
$CFG->cachejs = true;
$CFG->cachetemplates = true;
$CFG->themedesignermode = false;

// Increase limits for large syncs
ini_set('memory_limit', '512M');
ini_set('max_execution_time', 600);
```

## Support

For support and questions:

1. **Documentation**: Check this README and inline code comments
2. **Logs**: Review sync logs and Moodle error logs
3. **Testing**: Use dry-run modes to test before production
4. **Community**: Moodle community forums for general questions

## Version Information

- **Plugin Version**: 1.0.0
- **Moodle Compatibility**: 4.4+ (LTS)
- **PHP Requirements**: 8.1+
- **Database**: MySQL 8.0+ or PostgreSQL 13+

## License

This plugin is licensed under the GNU General Public License v3.0.

---

*PUCSR API Plugin - Enhancing Moodle for Academic Excellence*