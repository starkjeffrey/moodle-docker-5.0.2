# PUCSR API Specification

## Overview

The PUCSR API provides comprehensive functionality for managing composite grade structures and Student Information System (SIS) integration within Moodle. This RESTful API follows Moodle's web service standards and provides both read and write operations for grade management and data synchronization.

## Base URL

```
https://your-moodle-site.com/webservice/rest/server.php
```

## Authentication

All API requests require authentication using Moodle web service tokens.

### Token Authentication

Include the token in your request:

**As URL Parameter:**
```
?wstoken=YOUR_TOKEN_HERE
```

**As POST Data:**
```json
{
  "wstoken": "YOUR_TOKEN_HERE"
}
```

**As Header:**
```
Authorization: Bearer YOUR_TOKEN_HERE
```

### Required Parameters

All requests must include:
- `wstoken`: Your web service token
- `wsfunction`: The function name to call
- `moodlewsrestformat`: Response format (json, xml)

## Response Format

All responses follow this structure:

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "exception": null,
  "errorcode": null,
  "message": null
}
```

### Error Response

```json
{
  "exception": "moodle_exception",
  "errorcode": "error_code",
  "message": "Human readable error message",
  "debuginfo": "Additional debug information"
}
```

## Composite Grade Management

### Create Composite Structure

Creates an IEAP-4 style composite grade structure with weighted components.

**Function:** `local_pucsr_api_create_composite_structure`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| courseid | int | Yes | Course ID where structure will be created |
| structure | object | Yes | Grade structure configuration |

**Structure Object:**

```json
{
  "name": "IEAP-4",
  "components": [
    {
      "name": "Grammar",
      "weight": 0.5,
      "subitems": [
        {
          "name": "Quiz 1",
          "maxgrade": 100,
          "itemtype": "manual"
        }
      ]
    }
  ]
}
```

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_create_composite_structure",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "structure": {
      "name": "IEAP-4",
      "components": [
        {
          "name": "Grammar",
          "weight": 0.5,
          "subitems": [
            {"name": "Quiz 1", "maxgrade": 100, "itemtype": "manual"},
            {"name": "Quiz 2", "maxgrade": 100, "itemtype": "manual"}
          ]
        },
        {
          "name": "Writing",
          "weight": 0.5,
          "subitems": [
            {"name": "Essay 1", "maxgrade": 100, "itemtype": "manual"},
            {"name": "Essay 2", "maxgrade": 100, "itemtype": "manual"}
          ]
        }
      ]
    }
  }'
```

**Response:**

```json
{
  "main_category_id": 456,
  "components": [
    {
      "category_id": 789,
      "name": "Grammar",
      "weight": 0.5,
      "items": [
        {
          "id": 101,
          "name": "Quiz 1",
          "maxgrade": 100
        },
        {
          "id": 102,
          "name": "Quiz 2",
          "maxgrade": 100
        }
      ]
    },
    {
      "category_id": 790,
      "name": "Writing",
      "weight": 0.5,
      "items": [
        {
          "id": 103,
          "name": "Essay 1",
          "maxgrade": 100
        },
        {
          "id": 104,
          "name": "Essay 2",
          "maxgrade": 100
        }
      ]
    }
  ]
}
```

### Get Composite Grades

Retrieves student grades with optional component breakdown.

**Function:** `local_pucsr_api_get_composite_grades`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| courseid | int | Yes | Course ID |
| userid | int | No | Specific user ID (returns all if not specified) |
| include_breakdown | bool | No | Include component breakdown (default: true) |

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_get_composite_grades",
    "moodlewsrestformat": "json",
    "courseid": 123,
    "userid": 456,
    "include_breakdown": true
  }'
```

**Response:**

```json
{
  "courseid": 123,
  "structure_name": "IEAP-4",
  "grades": [
    {
      "userid": 456,
      "firstname": "John",
      "lastname": "Doe",
      "email": "john.doe@email.com",
      "composite_grade": 87.5,
      "components": [
        {
          "name": "Grammar",
          "weight": 0.5,
          "component_grade": 85.0,
          "items": [
            {
              "name": "Quiz 1",
              "maxgrade": 100,
              "grade": 80,
              "percentage": 80.0
            },
            {
              "name": "Quiz 2",
              "maxgrade": 100,
              "grade": 90,
              "percentage": 90.0
            }
          ]
        },
        {
          "name": "Writing",
          "weight": 0.5,
          "component_grade": 90.0,
          "items": [
            {
              "name": "Essay 1",
              "maxgrade": 100,
              "grade": 88,
              "percentage": 88.0
            },
            {
              "name": "Essay 2",
              "maxgrade": 100,
              "grade": 92,
              "percentage": 92.0
            }
          ]
        }
      ]
    }
  ]
}
```

### Update Composite Grades

Updates grades for specific items in the composite structure.

**Function:** `local_pucsr_api_update_composite_grades`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| updates | array | Yes | Array of grade updates |

**Update Object:**

```json
{
  "courseid": 123,
  "userid": 456,
  "itemid": 789,
  "grade": 85.5
}
```

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_update_composite_grades",
    "moodlewsrestformat": "json",
    "updates": [
      {
        "courseid": 123,
        "userid": 456,
        "itemid": 789,
        "grade": 85.5
      },
      {
        "courseid": 123,
        "userid": 457,
        "itemid": 789,
        "grade": 92.0
      }
    ]
  }'
```

**Response:**

```json
{
  "updates": [
    {
      "courseid": 123,
      "userid": 456,
      "itemid": 789,
      "grade": 85.5,
      "success": true
    },
    {
      "courseid": 123,
      "userid": 457,
      "itemid": 789,
      "grade": 92.0,
      "success": true
    }
  ]
}
```

## SIS Integration

### Sync Data

Comprehensive data synchronization between Moodle and SIS.

**Function:** `local_pucsr_api_sync_sis_data`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| sync_type | string | Yes | Type: grades, enrollments, users, all |
| direction | string | Yes | Direction: push, pull, both |
| courseid | int | No | Course ID for course-specific sync |
| term | string | No | Academic term filter |
| force | bool | No | Force sync even if already running |

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_sync_sis_data",
    "moodlewsrestformat": "json",
    "sync_type": "all",
    "direction": "both",
    "term": "2025-Spring"
  }'
```

**Response:**

```json
{
  "success": true,
  "sync_type": "all",
  "direction": "both",
  "results": {
    "sync_users": {
      "created": 15,
      "updated": 8,
      "errors": []
    },
    "pull_enrollments": {
      "enrolled": 142,
      "updated": 3,
      "courses_processed": ["IEAP4-001", "IEAP4-002"],
      "errors": []
    },
    "push_grades": {
      "success": true,
      "count": 89,
      "errors": []
    }
  }
}
```

### Push Grades to SIS

Pushes course grades to the SIS system.

**Function:** `local_pucsr_api_push_grades_to_sis`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| courseid | int | Yes | Course ID |
| userid | int | No | Specific user ID (optional) |

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_push_grades_to_sis",
    "moodlewsrestformat": "json",
    "courseid": 123
  }'
```

**Response:**

```json
{
  "success": true,
  "count": 25,
  "message": "Grades successfully pushed to SIS",
  "errors": []
}
```

### Pull Enrollments from SIS

Pulls enrollment data from the SIS system.

**Function:** `local_pucsr_api_pull_enrollments_from_sis`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| term | string | No | Academic term filter |
| course_code | string | No | Specific course code filter |

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_pull_enrollments_from_sis",
    "moodlewsrestformat": "json",
    "term": "2025-Spring"
  }'
```

**Response:**

```json
{
  "enrolled": 67,
  "updated": 5,
  "courses_processed": [
    "IEAP4-001",
    "IEAP4-002",
    "IEAP4-003"
  ],
  "errors": [
    {
      "student_id": "SIS_123456",
      "course_code": "IEAP4-004",
      "error": "Course not found in Moodle"
    }
  ]
}
```

## Reporting and Analytics

### Get Course Analytics

Retrieves comprehensive analytics for a course.

**Function:** `local_pucsr_api_get_course_analytics`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| courseid | int | Yes | Course ID |

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_get_course_analytics",
    "moodlewsrestformat": "json",
    "courseid": 123
  }'
```

**Response:**

```json
{
  "courseid": 123,
  "course_name": "IEAP-4 English",
  "total_students": 25,
  "grade_statistics": {
    "average": 82.5,
    "median": 85.0,
    "min": 65.0,
    "max": 98.0,
    "std_deviation": 8.2
  },
  "component_statistics": {
    "Grammar": {
      "average": 80.2,
      "completion_rate": 96.0
    },
    "Writing": {
      "average": 84.8,
      "completion_rate": 92.0
    }
  },
  "grade_distribution": {
    "A": 8,
    "B": 12,
    "C": 4,
    "D": 1,
    "F": 0
  }
}
```

### Get Sync Logs

Retrieves synchronization operation logs.

**Function:** `local_pucsr_api_get_sync_logs`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| sync_type | string | No | Filter by sync type |
| status | string | No | Filter by status |
| courseid | int | No | Filter by course |
| limit | int | No | Number of records to return |
| offset | int | No | Starting record offset |

**Example Request:**

```bash
curl -X POST "https://moodle.site.com/webservice/rest/server.php" \
  -H "Content-Type: application/json" \
  -d '{
    "wstoken": "your_token",
    "wsfunction": "local_pucsr_api_get_sync_logs",
    "moodlewsrestformat": "json",
    "sync_type": "grades",
    "status": "success",
    "limit": 10
  }'
```

**Response:**

```json
{
  "logs": [
    {
      "id": 123,
      "sync_type": "grades",
      "courseid": 456,
      "direction": "push",
      "records_processed": 25,
      "records_success": 25,
      "records_failed": 0,
      "status": "success",
      "error_message": null,
      "timecreated": 1642678800,
      "timemodified": 1642678850
    }
  ],
  "total_count": 45,
  "has_more": true
}
```

## Error Codes

### Common Error Codes

| Code | Description | Resolution |
|------|-------------|------------|
| `invalid_token` | Invalid or expired web service token | Regenerate token |
| `permission_denied` | Insufficient permissions | Check user capabilities |
| `invalid_courseid` | Course ID not found | Verify course exists |
| `structure_exists` | Composite structure already exists | Use existing or delete first |
| `invalid_weights` | Component weights don't sum to 1.0 | Adjust weight values |
| `sis_not_enabled` | SIS integration disabled | Enable in plugin settings |
| `sis_connection_failed` | Cannot connect to SIS | Check SIS configuration |
| `sync_in_progress` | Sync already running | Wait or use force parameter |

### Validation Errors

| Field | Error | Description |
|-------|-------|-------------|
| `grade` | `invalid_grade_value` | Grade outside min/max range |
| `weight` | `invalid_weight` | Weight not between 0 and 1 |
| `courseid` | `course_not_found` | Course does not exist |
| `userid` | `user_not_enrolled` | User not enrolled in course |

## Rate Limiting

The API implements rate limiting to ensure system stability:

- **Default Limit**: 100 requests per hour per token
- **Burst Limit**: 10 requests per minute
- **Large Operations**: Bulk syncs count as multiple requests

### Rate Limit Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 85
X-RateLimit-Reset: 1642682400
```

### Rate Limit Exceeded Response

```json
{
  "exception": "rate_limit_exceeded",
  "errorcode": "api_rate_limit",
  "message": "API rate limit exceeded. Try again later.",
  "retry_after": 3600
}
```

## Best Practices

### Performance Optimization

1. **Batch Operations**: Group multiple updates into single requests
2. **Selective Syncing**: Use filters to limit data scope
3. **Caching**: Implement client-side caching for frequently accessed data
4. **Async Processing**: Use background processing for large operations

### Error Handling

1. **Retry Logic**: Implement exponential backoff for temporary failures
2. **Validation**: Validate input data before sending requests
3. **Logging**: Log all API interactions for debugging
4. **Monitoring**: Monitor error rates and response times

### Security

1. **Token Security**: Store tokens securely, rotate regularly
2. **HTTPS Only**: Always use HTTPS for API communications
3. **IP Restrictions**: Limit token usage to specific IP addresses
4. **Input Sanitization**: Sanitize all input data

### Data Integrity

1. **Backup Before Bulk Changes**: Always backup before large operations
2. **Validation**: Validate data consistency after operations
3. **Transaction Safety**: Use appropriate transaction boundaries
4. **Rollback Plans**: Have rollback procedures for failed operations

## SDKs and Libraries

### PHP SDK Example

```php
<?php
class PUCSRApiClient {
    private $baseUrl;
    private $token;

    public function __construct($baseUrl, $token) {
        $this->baseUrl = $baseUrl;
        $this->token = $token;
    }

    public function createCompositeStructure($courseid, $structure) {
        return $this->apiCall('local_pucsr_api_create_composite_structure', [
            'courseid' => $courseid,
            'structure' => $structure
        ]);
    }

    public function getCompositeGrades($courseid, $userid = null) {
        return $this->apiCall('local_pucsr_api_get_composite_grades', [
            'courseid' => $courseid,
            'userid' => $userid,
            'include_breakdown' => true
        ]);
    }

    private function apiCall($function, $params) {
        $data = array_merge($params, [
            'wstoken' => $this->token,
            'wsfunction' => $function,
            'moodlewsrestformat' => 'json'
        ]);

        $ch = curl_init($this->baseUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json'
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        return json_decode($response, true);
    }
}

// Usage
$client = new PUCSRApiClient(
    'https://moodle.site.com/webservice/rest/server.php',
    'your_token_here'
);

$structure = [
    'name' => 'IEAP-4',
    'components' => [
        [
            'name' => 'Grammar',
            'weight' => 0.5,
            'subitems' => [
                ['name' => 'Quiz 1', 'maxgrade' => 100, 'itemtype' => 'manual']
            ]
        ]
    ]
];

$result = $client->createCompositeStructure(123, $structure);
```

### JavaScript SDK Example

```javascript
class PUCSRApiClient {
    constructor(baseUrl, token) {
        this.baseUrl = baseUrl;
        this.token = token;
    }

    async createCompositeStructure(courseid, structure) {
        return this.apiCall('local_pucsr_api_create_composite_structure', {
            courseid,
            structure
        });
    }

    async getCompositeGrades(courseid, userid = null) {
        return this.apiCall('local_pucsr_api_get_composite_grades', {
            courseid,
            userid,
            include_breakdown: true
        });
    }

    async apiCall(wsfunction, params) {
        const data = {
            wstoken: this.token,
            wsfunction,
            moodlewsrestformat: 'json',
            ...params
        };

        const response = await fetch(this.baseUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });

        return response.json();
    }
}

// Usage
const client = new PUCSRApiClient(
    'https://moodle.site.com/webservice/rest/server.php',
    'your_token_here'
);

const structure = {
    name: 'IEAP-4',
    components: [
        {
            name: 'Grammar',
            weight: 0.5,
            subitems: [
                { name: 'Quiz 1', maxgrade: 100, itemtype: 'manual' }
            ]
        }
    ]
};

client.createCompositeStructure(123, structure)
    .then(result => console.log(result))
    .catch(error => console.error(error));
```

---

*PUCSR API Specification - Version 1.0*