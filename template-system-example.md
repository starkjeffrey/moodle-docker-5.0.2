# Template-Based Storage System Explanation

## How It Works: Students Still See EVERYTHING

### Current System (Inefficient):
Every assignment stores the ENTIRE instruction text:

```
Assignment 1: "Write a descriptive paragraph about your favorite food. Include a topic sentence,
               5 supporting sentences, and a concluding sentence. Use adjectives to describe
               how it looks, sounds, feels, smells." (300 bytes)

Assignment 2: "Write a descriptive paragraph about your best friend. Include a topic sentence,
               5 supporting sentences, and a concluding sentence. Use adjectives to describe
               how it looks, sounds, feels, smells." (302 bytes)

Assignment 3: "Write a descriptive paragraph about your hometown. Include a topic sentence,
               5 supporting sentences, and a concluding sentence. Use adjectives to describe
               how it looks, sounds, feels, smells." (298 bytes)
```
**Total Storage: 900 bytes for 3 similar assignments**

### New System (Template-Based):

#### Step 1: Create One Template
```
Template ID: 1
Template Name: "Descriptive Paragraph Template"
Template Text: "Write a descriptive paragraph about {{TOPIC}}. Include a topic sentence,
                {{NUM}} supporting sentences, and a concluding sentence. Use adjectives
                to describe how it looks, sounds, feels, smells."
```
**Template Storage: 200 bytes (stored once)**

#### Step 2: Store Only Variables for Each Assignment
```
Assignment 1: {template: 1, topic: "your favorite food", num: 5}    (40 bytes)
Assignment 2: {template: 1, topic: "your best friend", num: 5}      (40 bytes)
Assignment 3: {template: 1, topic: "your hometown", num: 5}         (40 bytes)
```
**Variables Storage: 120 bytes total**

**Total New Storage: 320 bytes (vs 900 bytes) = 64% savings**

## What Students See (UNCHANGED):

### Before Optimization:
Student opens Assignment 1 and sees:
> "Write a descriptive paragraph about your favorite food. Include a topic sentence, 5 supporting sentences, and a concluding sentence. Use adjectives to describe how it looks, sounds, feels, smells."

### After Optimization:
Student opens Assignment 1 and STILL sees:
> "Write a descriptive paragraph about your favorite food. Include a topic sentence, 5 supporting sentences, and a concluding sentence. Use adjectives to describe how it looks, sounds, feels, smells."

**The system automatically combines template + variables when displaying to students!**

## Real Example from Your IFL Data:

### Current Storage for 10 Similar Writing Assignments:
```
10 assignments × 1,000 bytes average = 10,000 bytes
Each stores: "Write a 5-paragraph narrative essay about [topic]. Include introduction
             with thesis statement, 3 body paragraphs, and conclusion..."
```

### Optimized Storage:
```
1 template (500 bytes) + 10 variable sets (10 × 50 bytes) = 1,000 bytes
90% reduction!
```

## Benefits:

1. **Students see identical content** - No change in their experience
2. **Teachers can update all assignments at once** - Change template, all assignments update
3. **Faster page loads** - Less data to transfer
4. **Easier maintenance** - Fix typos in one place
5. **Better consistency** - All similar assignments use same instructions
6. **Storage savings** - 70-90% reduction in database size

## Implementation in Moodle:

```php
// When student requests assignment:
function display_assignment($assignment_id) {
    // Get assignment data
    $assignment = get_assignment($assignment_id);

    if ($assignment->template_id) {
        // Get template
        $template = get_template($assignment->template_id);

        // Replace variables
        $full_text = str_replace(
            ['{{TOPIC}}', '{{NUM}}'],
            [$assignment->topic, $assignment->num],
            $template->text
        );

        // Display to student (they see full instructions)
        return $full_text;
    }
}
```

## Common Templates for Your IFL Courses:

1. **Descriptive Paragraph Template** (used 25 times)
2. **Narrative Essay Template** (used 18 times)
3. **Opinion Paragraph Template** (used 15 times)
4. **Comparison Essay Template** (used 12 times)
5. **Process Paragraph Template** (used 10 times)

Instead of storing 80 full assignments, store 5 templates + 80 small variable sets!

## Visual Comparison:

### Storage Space:
```
Current:  ████████████████████████████████ (80KB)
Template: ████ (8KB)

Savings:  ════════════════════════════════ (72KB saved!)
```

### What Changes for Users:
```
Teachers: ✓ Easier to manage
          ✓ Update many assignments at once
          ✓ Better consistency

Students: ✗ Nothing changes!
          ✗ Same instructions
          ✗ Same experience
```