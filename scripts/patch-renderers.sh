#!/bin/bash
set -e

RENDERER_FILES=(
    "/bitnami/moodle/lib/classes/output/core_renderer.php"
    "/bitnami/moodle/lib/classes/output/core_renderer_cli.php"
    "/bitnami/moodle/lib/classes/output/core_renderer_ajax.php"
    "/bitnami/moodle/lib/classes/output/core_renderer_maintenance.php"
)

METHOD_CODE='
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
'

echo "Patching Moodle core renderer files..."

for file in "${RENDERER_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Patching $file"
        # Backup original
        cp "$file" "${file}.bak" 2>/dev/null || true

        # Check if method already exists
        if ! grep -q "firstview_fakeblocks" "$file"; then
            # Add method before final closing brace
            sed -i '/^}$/i\'"$METHOD_CODE"'' "$file"
            echo "  -> Added firstview_fakeblocks method"
        else
            echo "  -> Method already exists, skipping"
        fi
    else
        echo "File not found: $file"
    fi
done

echo "Renderer patching completed!"