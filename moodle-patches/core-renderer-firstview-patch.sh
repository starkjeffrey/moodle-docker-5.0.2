#!/bin/bash
# Permanent fix for missing firstview_fakeblocks method in Moodle core renderers
# This patch adds the method to the main core_renderer.php to ensure compatibility
# with themes that call this method

set -e

RENDERER_FILE="/bitnami/moodle/lib/classes/output/core_renderer.php"

if [ ! -f "$RENDERER_FILE" ]; then
    echo "Core renderer file not found: $RENDERER_FILE"
    exit 1
fi

if grep -q "firstview_fakeblocks" "$RENDERER_FILE"; then
    echo "Method already exists in core_renderer.php - no patch needed"
    exit 0
fi

echo "Applying firstview_fakeblocks patch to core_renderer.php..."

# Create backup
cp "$RENDERER_FILE" "${RENDERER_FILE}.original"

# Create the method
cat > /tmp/method_patch.php << 'EOF'

    /**
     * See if this is the first view of the current cm in the session if it has fake blocks.
     * Fallback method added for theme compatibility.
     * @return boolean true if the page has fakeblocks and this is the first visit.
     */
    public function firstview_fakeblocks(): bool {
        global $SESSION;
        $firstview = false;
        if ($this->page->cm) {
            if (!$this->page->blocks->region_has_fakeblocks("side-pre")) {
                return false;
            }
            if (!property_exists($SESSION, "firstview_fakeblocks")) {
                $SESSION->firstview_fakeblocks = [];
            }
            if (array_key_exists($this->page->cm->id, $SESSION->firstview_fakeblocks)) {
                $firstview = false;
            } else {
                $SESSION->firstview_fakeblocks[$this->page->cm->id] = true;
                $firstview = true;
                if (count($SESSION->firstview_fakeblocks) > 100) {
                    array_shift($SESSION->firstview_fakeblocks);
                }
            }
        }
        return $firstview;
    }
EOF

# Find the last line with just }
line_num=$(grep -n "^}$" "$RENDERER_FILE" | tail -1 | cut -d: -f1)

if [ -z "$line_num" ]; then
    echo "Error: Could not find insertion point in core_renderer.php"
    exit 1
fi

# Insert method before the last closing brace
head -n $((line_num - 1)) "$RENDERER_FILE" > /tmp/patched_renderer.php
cat /tmp/method_patch.php >> /tmp/patched_renderer.php
tail -n +$line_num "$RENDERER_FILE" >> /tmp/patched_renderer.php
mv /tmp/patched_renderer.php "$RENDERER_FILE"

# Verify syntax
if php -l "$RENDERER_FILE" > /dev/null 2>&1; then
    echo "✅ Patch applied successfully - core_renderer.php now has firstview_fakeblocks method"
    rm -f /tmp/method_patch.php
else
    echo "❌ Syntax error detected - restoring original file"
    cp "${RENDERER_FILE}.original" "$RENDERER_FILE"
    exit 1
fi