#!/bin/bash
#
# Parallel Image Building with Packer
# Builds golden images for all 11 OSes simultaneously
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_PARALLEL=${MAX_PARALLEL:-4}  # Adjust based on CPU cores

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "========================================"
echo "Parallel Packer Image Building"
echo "========================================"
echo ""
echo "Building golden images for 11 operating systems"
echo "Max parallel builds: $MAX_PARALLEL"
echo "CPU cores available: $(sysctl -n hw.ncpu)"
echo ""

# Check Packer is installed
if ! command -v packer &> /dev/null; then
    log_error "Packer not found. Installing..."
    brew install packer
fi

log_success "Packer installed: $(packer version)"
echo ""

# Create build log directory
mkdir -p logs

# Define all OS builds
declare -a BUILDS=(
    "ubuntu:packer-ubuntu-zfs.pkr.hcl"
    "debian:packer-debian-zfs.pkr.hcl"
    "rocky:packer-rocky-zfs.pkr.hcl"
    "fedora:packer-fedora-zfs.pkr.hcl"
    "arch:packer-arch-zfs.pkr.hcl"
    "freebsd:packer-freebsd-zfs.pkr.hcl"
    "truenas-scale:packer-truenas-scale.pkr.hcl"
    "truenas-core:packer-truenas-core.pkr.hcl"
    "openbsd:packer-openbsd-zfs.pkr.hcl"
    "netbsd:packer-netbsd-zfs.pkr.hcl"
    "openindiana:packer-openindiana.pkr.hcl"
)

# Build function
build_image() {
    local os_name=$1
    local template=$2
    local log_file="logs/${os_name}-build.log"
    
    if [ ! -f "$template" ]; then
        echo "⊘ $os_name: Template not found, skipping" | tee -a "$log_file"
        return 1
    fi
    
    echo "🔨 Building $os_name..." | tee -a "$log_file"
    local start_time=$(date +%s)
    
    if packer build "$template" >> "$log_file" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✓ $os_name: SUCCESS (${duration}s)" | tee -a "$log_file"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✗ $os_name: FAILED (${duration}s)" | tee -a "$log_file"
        return 1
    fi
}

export -f build_image
export SCRIPT_DIR

# Use GNU parallel if available, otherwise xargs
if command -v parallel &> /dev/null; then
    log_info "Using GNU Parallel for maximum speed"
    
    # Build all images in parallel
    printf '%s\n' "${BUILDS[@]}" | parallel -j "$MAX_PARALLEL" --colsep ':' build_image {1} {2}
    
elif command -v xargs &> /dev/null; then
    log_info "Using xargs for parallel builds"
    
    # Build using xargs
    printf '%s\n' "${BUILDS[@]}" | xargs -P "$MAX_PARALLEL" -I {} bash -c '
        IFS=: read -r name template <<< "{}"
        build_image "$name" "$template"
    '
else
    log_info "No parallel tool found, building sequentially"
    
    # Sequential fallback
    for build in "${BUILDS[@]}"; do
        IFS=: read -r name template <<< "$build"
        build_image "$name" "$template"
    done
fi

echo ""
echo "========================================"
echo "Build Summary"
echo "========================================"
echo ""

# Count results
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

for build in "${BUILDS[@]}"; do
    IFS=: read -r name template <<< "$build"
    TOTAL=$((TOTAL + 1))
    
    if [ -f "output-${name}/disk.qcow2" ] || [ -f "output-${name}/${name}.qcow2" ]; then
        SUCCESS=$((SUCCESS + 1))
        echo -e "${GREEN}✓${NC} $name: Image built"
    elif [ -f "logs/${name}-build.log" ] && grep -q "FAILED" "logs/${name}-build.log"; then
        FAILED=$((FAILED + 1))
        echo -e "${RED}✗${NC} $name: Build failed (see logs/${name}-build.log)"
    else
        SKIPPED=$((SKIPPED + 1))
        echo -e "${CYAN}⊘${NC} $name: Skipped (no template)"
    fi
done

echo ""
echo "Total: $TOTAL"
echo "Success: $SUCCESS"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"
echo ""

if [ $SUCCESS -gt 0 ]; then
    log_success "Built $SUCCESS golden images successfully!"
    echo ""
    echo "Next: Run parallel tests with ./test-all-golden-images.sh"
fi

if [ $FAILED -gt 0 ]; then
    log_error "$FAILED builds failed. Check logs/ directory for details."
fi
