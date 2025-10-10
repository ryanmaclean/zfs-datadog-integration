#!/bin/bash
#
# Download and Benchmark VM Images
# Measures actual download times and sizes
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_FILE="${SCRIPT_DIR}/download-benchmark-results.md"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Start results file
cat > "$RESULTS_FILE" <<EOF
# VM Image Download Benchmarks

**Date**: $(date)  
**Architecture**: $(uname -m)  
**Connection**: $(curl -s https://speed.cloudflare.com/meta | jq -r '.clientIp' 2>/dev/null || echo "Unknown")

## Results

EOF

benchmark_download() {
    local name=$1
    local url=$2
    local file=$3
    
    echo -e "${BLUE}Downloading: $name${NC}"
    echo "URL: $url"
    
    if [ -f "$file" ]; then
        local size=$(ls -lh "$file" | awk '{print $5}')
        echo -e "${GREEN}✓ Already downloaded ($size)${NC}"
        echo "| $name | Cached | $size | - |" >> "$RESULTS_FILE"
        return 0
    fi
    
    local start=$(date +%s)
    
    # Download with progress
    curl -L --progress-bar -o "$file" "$url"
    
    local end=$(date +%s)
    local duration=$((end - start))
    local size=$(ls -lh "$file" | awk '{print $5}')
    local size_bytes=$(ls -l "$file" | awk '{print $5}')
    local speed_mbps=$(echo "scale=2; $size_bytes / $duration / 1024 / 1024" | bc)
    
    echo -e "${GREEN}✓ Downloaded in ${duration}s ($size, ${speed_mbps} MB/s)${NC}"
    echo "| $name | ${duration}s | $size | ${speed_mbps} MB/s |" >> "$RESULTS_FILE"
    echo ""
}

echo -e "${CYAN}VM Image Download Benchmarks${NC}"
echo "======================================"
echo ""

# Add table header to results
cat >> "$RESULTS_FILE" <<EOF
| Image | Download Time | Size | Speed |
|-------|---------------|------|-------|
EOF

# FreeBSD ARM64
benchmark_download \
    "FreeBSD 14.3 ARM64" \
    "https://download.freebsd.org/releases/VM-IMAGES/14.3-RELEASE/aarch64/Latest/FreeBSD-14.3-RELEASE-arm64-aarch64-BASIC-CLOUDINIT.qcow2.xz" \
    "freebsd-arm64.qcow2.xz"

# Extract if needed
if [ -f "freebsd-arm64.qcow2.xz" ] && [ ! -f "freebsd-arm64.qcow2" ]; then
    echo "Extracting FreeBSD image..."
    start=$(date +%s)
    xz -d -k freebsd-arm64.qcow2.xz
    end=$(date +%s)
    echo "Extracted in $((end - start))s"
fi

# TrueNAS SCALE
benchmark_download \
    "TrueNAS SCALE 24.04.2" \
    "https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/TrueNAS-SCALE-24.04.2.2.iso" \
    "truenas-scale.iso"

# TrueNAS CORE
benchmark_download \
    "TrueNAS CORE 13.3" \
    "https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/TrueNAS-13.3-RELEASE.iso" \
    "truenas-core.iso"

# Summary
cat >> "$RESULTS_FILE" <<EOF

## Summary

**Total Images**: 3  
**FreeBSD**: Native ARM64 cloud image  
**TrueNAS SCALE**: x86_64 ISO (Debian-based)  
**TrueNAS CORE**: x86_64 ISO (FreeBSD-based)  

## Boot Time Estimates

| System | Architecture | Boot Time (Estimated) |
|--------|--------------|----------------------|
| FreeBSD 14.2 | ARM64 Native | ~30-60s |
| TrueNAS SCALE | x86_64 Emulated | ~5-10 minutes (first boot) |
| TrueNAS CORE | x86_64 Emulated | ~5-10 minutes (first boot) |

## Usage

\`\`\`bash
# FreeBSD (fastest)
./qemu-freebsd.sh

# TrueNAS SCALE (slower, emulated)
./qemu-truenas-scale.sh

# TrueNAS CORE (slower, emulated)
./qemu-truenas-core.sh
\`\`\`

## Notes

- ARM64 native images boot much faster
- x86_64 emulation on ARM64 is ~10x slower
- First boot includes installation time
- Subsequent boots are faster (30-60s)
- QEMU installation time: ~60s (one-time)
EOF

echo ""
echo -e "${GREEN}======================================"
echo "Benchmark Complete!"
echo "======================================${NC}"
echo ""
echo "Results saved to: $RESULTS_FILE"
cat "$RESULTS_FILE"
