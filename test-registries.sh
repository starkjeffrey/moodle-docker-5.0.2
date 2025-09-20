#!/bin/bash

echo "Testing Container Registry Access and Image Sizes"
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_pull() {
    local registry=$1
    local image=$2
    local full_image="${registry}${image}"

    echo -e "\n${YELLOW}Testing: ${full_image}${NC}"

    # Try to pull image metadata only (faster)
    if docker manifest inspect "$full_image" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Available${NC}"

        # Get image size
        size=$(docker manifest inspect "$full_image" 2>/dev/null | jq -r '.config.size' 2>/dev/null || echo "unknown")

        if [ "$size" != "unknown" ]; then
            size_mb=$((size / 1048576))
            echo "  Size: ~${size_mb} MB (config)"
        fi

        # Check for slim/alpine variants
        echo "  Checking for slim variants..."
        for variant in "-slim" "-alpine" "-minimal"; do
            variant_image="${full_image}${variant}"
            if docker manifest inspect "$variant_image" > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓ Slim variant available: ${variant}${NC}"
            fi
        done

        return 0
    else
        echo -e "${RED}✗ Not available or requires authentication${NC}"
        return 1
    fi
}

echo -e "\n${YELLOW}=== MOODLE IMAGES ===${NC}"
echo "Standard Bitnami Moodle images (Debian-based, ~800-900MB):"

# Test Moodle images from different registries
test_pull "registry.hub.docker.com/" "bitnami/moodle:5.0.2"
test_pull "ghcr.io/" "bitnami/moodle:5.0.2"
test_pull "quay.io/" "bitnami/moodle:5.0.2"
test_pull "public.ecr.aws/" "bitnami/moodle:5.0.2"

echo -e "\n${YELLOW}=== MARIADB IMAGES ===${NC}"
echo "Standard Bitnami MariaDB images (Debian-based, ~400-500MB):"

# Test MariaDB images
test_pull "registry.hub.docker.com/" "bitnami/mariadb:11.4"
test_pull "ghcr.io/" "bitnami/mariadb:11.4"
test_pull "quay.io/" "bitnami/mariadb:11.4"
test_pull "public.ecr.aws/" "bitnami/mariadb:11.4"

# Test official MariaDB (smaller, Alpine-based)
echo -e "\n${YELLOW}Testing Official MariaDB (Alpine-based, ~100-150MB):${NC}"
test_pull "registry.hub.docker.com/" "mariadb:11.4-alpine"
test_pull "registry.hub.docker.com/" "mariadb:11.4"

echo -e "\n${YELLOW}=== REDIS IMAGES ===${NC}"
echo "Standard Bitnami Redis images (Debian-based, ~100-150MB):"

# Test Redis images
test_pull "registry.hub.docker.com/" "bitnami/redis:7.2"
test_pull "ghcr.io/" "bitnami/redis:7.2"
test_pull "quay.io/" "bitnami/redis:7.2"
test_pull "public.ecr.aws/" "bitnami/redis:7.2"

# Test official Redis (smaller, Alpine-based)
echo -e "\n${YELLOW}Testing Official Redis (Alpine-based, ~30-50MB):${NC}"
test_pull "registry.hub.docker.com/" "redis:7.2-alpine"
test_pull "registry.hub.docker.com/" "redis:7.2"

echo -e "\n${YELLOW}=== ALTERNATIVE SLIM OPTIONS ===${NC}"
echo "Note: Bitnami images are production-grade but larger due to:"
echo "  - Full Debian base (not Alpine)"
echo "  - Pre-configured with best practices"
echo "  - Include monitoring and health check tools"
echo "  - Production-ready security settings"

echo -e "\n${GREEN}Recommendations for smaller images:${NC}"
echo "1. Use official Alpine variants for MariaDB/Redis (70-80% smaller)"
echo "2. For Moodle, consider building custom Alpine-based image"
echo "3. Use multi-stage builds to reduce final image size"
echo "4. Consider distroless images for production"

echo -e "\n${YELLOW}=== FASTEST REGISTRIES (typically) ===${NC}"
echo "1. registry.hub.docker.com - Docker Hub direct"
echo "2. ghcr.io - GitHub Container Registry (fast in US/EU)"
echo "3. public.ecr.aws - AWS ECR Public (fast globally)"
echo "4. quay.io - Red Hat Quay (good for enterprise)"

echo -e "\n${GREEN}Test complete!${NC}"