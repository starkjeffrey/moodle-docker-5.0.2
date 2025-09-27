# Moodle Database Analysis & Optimization Report

## Database Overview
**Database restored from**: `data/tjm1PpXrZPcj.sql.gz` (1.6GB compressed)
**Total tables**: 210
**Database size**: ~697 MB
**Moodle version**: 4.5.4+

## Key Finding: No Question Banks Present

After thorough analysis, **this database backup does NOT contain question bank tables**. The following tables are missing:
- `mdl_question` - Core question storage
- `mdl_question_categories` - Question organization
- `mdl_quiz` - Quiz activities
- `mdl_quiz_attempts` - Student quiz attempts
- `mdl_qtype_*` - Question type specific tables

## Available Assessment Data

Instead, your database contains extensive **assignment-based assessments**:

### 📊 Statistics:
- **3,578** assignments across courses
- **89,810** assignment submissions
- **68,310** graded submissions
- **2,910** courses
- **34-89 students per assignment** (based on sample)

### 📁 Key Tables for Assessment Data:
1. **mdl_assign** (3.40 MB) - Assignment configurations
2. **mdl_assign_submission** (14.56 MB) - Student submissions
3. **mdl_assign_grades** (8.29 MB) - Grading data
4. **mdl_assignsubmission_onlinetext** (7.56 MB) - Text submissions
5. **mdl_assignfeedback_comments** (4.27 MB) - Teacher feedback

## Optimization Opportunities

### 1. **Assignment Data Extraction & Optimization**
```bash
# Export all assignments with metadata (already created)
docker exec -i moodle-4-5-mariadb mysql -u root -pmoodle_45_root_password \
  bitnami_moodle_45 < extract-assignments.sql > assignments_complete.csv
```

### 2. **Performance Optimizations**

#### A. Database Indexes
```sql
-- Add indexes for faster assignment queries
ALTER TABLE mdl_assign_submission ADD INDEX idx_assignment_status (assignment, status);
ALTER TABLE mdl_assign_grades ADD INDEX idx_assignment_grade (assignment, grade);
ALTER TABLE mdl_assign_submission ADD INDEX idx_user_assignment (userid, assignment);
```

#### B. Data Archiving
```sql
-- Archive old submissions (older than 2 years)
CREATE TABLE mdl_assign_submission_archive AS
SELECT * FROM mdl_assign_submission
WHERE timemodified < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 2 YEAR));

-- Remove archived data from main table
DELETE FROM mdl_assign_submission
WHERE timemodified < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 2 YEAR));
```

### 3. **Content Migration Strategy**

Since you want question banks but only have assignments, here are your options:

#### Option A: Convert Assignments to Question Banks
```sql
-- Extract assignment questions as a base for question bank
SELECT
    a.id,
    a.name as question_name,
    a.intro as question_text,
    a.grade as default_grade,
    c.fullname as category
FROM mdl_assign a
JOIN mdl_course c ON a.course = c.id
WHERE a.intro IS NOT NULL AND a.intro != '';
```

#### Option B: Import Question Banks
If you have question banks in another Moodle instance:
1. Export questions using Moodle's question bank export (Moodle XML format)
2. Import into a fresh Moodle 5.0.2 instance
3. Migrate assignment data separately

### 4. **Bulk Operations Scripts**

I've created helper scripts for data management:

#### Extract All Assessment Data
```bash
#!/bin/bash
# extract-all-assessments.sh
docker exec moodle-4-5-mariadb mysqldump \
  -u root -pmoodle_45_root_password \
  --single-transaction \
  --tables mdl_assign mdl_assign_submission mdl_assign_grades \
  bitnami_moodle_45 > assessments_backup.sql
```

#### Clean Duplicate Submissions
```sql
-- Remove duplicate submissions (keep latest)
DELETE s1 FROM mdl_assign_submission s1
INNER JOIN mdl_assign_submission s2
WHERE s1.id < s2.id
  AND s1.assignment = s2.assignment
  AND s1.userid = s2.userid;
```

## Recommendations

### Immediate Actions:
1. ✅ **Export assignment data** for backup (completed: `assignments_export.tsv`)
2. 🔧 **Add database indexes** for performance improvement
3. 📊 **Analyze submission patterns** to identify inactive courses

### Medium-term Actions:
1. 🔄 **Migrate to Moodle 5.0.2** with fresh installation
2. 📝 **Create question banks** from assignment descriptions
3. 🗄️ **Archive old data** to improve performance

### For Question Banks:
Since you specifically wanted question banks but they're not in this backup:
1. Check if you have another backup with quiz/question data
2. Consider using Moodle's built-in tools to create question banks from your assignments
3. Use H5P or other interactive content tools as alternatives

## Data Files Created
- `assignments_export.tsv` - Sample assignment data export
- `extract-assignments.sql` - SQL script for full extraction
- `analyze-moodle-content.sql` - Database analysis queries

## Next Steps
Would you like me to:
1. Extract specific course assignments?
2. Create a migration plan to Moodle 5.0.2?
3. Generate question bank templates from your assignment data?
4. Optimize specific tables for better performance?