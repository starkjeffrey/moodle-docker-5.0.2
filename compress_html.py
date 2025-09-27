import re
import json
import sys

def clean_html(text):
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    # Remove HTML entities
    text = re.sub(r'&[^;]+;', ' ', text)
    # Compress multiple spaces
    text = re.sub(r'\s+', ' ', text)
    # Remove leading/trailing whitespace
    return text.strip()

def extract_template_pattern(text):
    """Extract common patterns from assignment text"""
    patterns = {
        'paragraph_writing': r'Write a.+paragraph',
        'essay_writing': r'Write a.+essay',
        'sentences_requirement': r'at least (\d+) sentences',
        'word_count': r'(\d+)\s*words',
        'topic_sentence': r'topic sentence',
        'supporting_sentences': r'supporting sentences',
        'conclusion': r'concluding sentence'
    }

    found_patterns = {}
    for name, pattern in patterns.items():
        if re.search(pattern, text, re.IGNORECASE):
            found_patterns[name] = True

    return found_patterns

def compress_assignment(assignment_text):
    """Compress assignment to template + variables"""
    cleaned = clean_html(assignment_text)
    patterns = extract_template_pattern(cleaned)

    # Determine assignment type
    if 'essay_writing' in patterns:
        template_type = 'essay'
    elif 'paragraph_writing' in patterns:
        template_type = 'paragraph'
    else:
        template_type = 'general'

    # Extract key information
    compressed = {
        'type': template_type,
        'patterns': patterns,
        'word_count': len(cleaned.split()),
        'compressed_text': cleaned[:200] if len(cleaned) > 200 else cleaned
    }

    return compressed

# Process assignments
assignments = []
with open('ifl_original.tsv', 'r') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) >= 5:
            assignment_id = parts[0]
            name = parts[1]
            original_size = parts[3]
            content = parts[4]

            compressed = compress_assignment(content)
            compressed['id'] = assignment_id
            compressed['name'] = name
            compressed['original_size'] = original_size
            assignments.append(compressed)

# Save compressed data
with open('ifl_compressed.json', 'w') as f:
    json.dump(assignments, f, indent=2)

# Calculate compression stats
original_total = sum(int(a.get('original_size', 0)) for a in assignments if a.get('original_size', '').isdigit())
compressed_total = sum(len(json.dumps(a)) for a in assignments)

print(f"Original size: {original_total} bytes ({original_total/1024:.2f} KB)")
print(f"Compressed size: {compressed_total} bytes ({compressed_total/1024:.2f} KB)")
print(f"Compression ratio: {(1 - compressed_total/original_total)*100:.2f}% reduction")
