#!/bin/bash
#
# Quick VM Download Benchmark
# Measures download and setup time for each VM image
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${CYAN}VM Image Download & Setup Benchmarks${NC}"
echo "======================================"
echo ""

# FreeBSD ARM64
echo -e "${BLUE}1. FreeBSD 14.2 ARM64${NC}"
echo "   Image: FreeBSD-14.2-RELEASE-arm64-aarch64-BASIC-CLOUDINIT.qcow2.xz"
echo "   URL: https://download.freebsd.org/releases/VM-IMAGES/14.2-RELEASE/aarch64/Latest/"
if [ -f "freebsd-arm64.qcow2" ]; then
    SIZE=$(ls -lh freebsd-arm64.qcow2 | awk '{print $5}')
    echo "   Status: ✓ Downloaded ($SIZE)"
else
    echo "   Status: Not downloaded"
    echo "   Downloading..."
    START=$(date +%s)
    curl -L -o freebsd-arm64.qcow2.xz "https://download.freebsd.org/releases/VM-IMAGES/14.2-RELEASE/aarch64/Latest/FreeBSD-14.2-RELEASE-arm64-aarch64-BASIC-CLOUDINIT.qcow2.xz" 2>&1 | grep -E "%" | tail -5
    xz -d freebsd-arm64.qcow2.xz
    END=$(date +%s)
    DURATION=$((END - START))
    SIZE=$(ls -lh freebsd-arm64.qcow2 | awk '{print $5}')
    echo -e "   ${GREEN}✓ Downloaded in ${DURATION}s ($SIZE)${NC}"
fi
echo ""

# TrueNAS SCALE
echo -e "${BLUE}2. TrueNAS SCALE 24.04${NC}"
echo "   Image: TrueNAS-SCALE-24.04.2.2.iso"
echo "   URL: https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/"
if [ -f "truenas-scale.iso" ]; then
    SIZE=$(ls -lh truenas-scale.iso | awk '{print $5}')
    echo "   Status: ✓ Downloaded ($SIZE)"
else
    echo "   Status: Not downloaded"
    echo "   Downloading (1.4GB)..."
    START=$(date +%s)
    curl -L -o truenas-scale.iso "https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/TrueNAS-SCALE-24.04.2.2.iso" 2>&1 | grep -E "%" | tail -10
    END=$(date +%s)
    DURATION=$((END - START))
    SIZE=$(ls -lh truenas-scale.iso | awk '{print $5}')
    echo -e "   ${GREEN}✓ Downloaded in ${DURATION}s ($SIZE)${NC}"
fi
echo ""

# TrueNAS CORE
echo -e "${BLUE}3. TrueNAS CORE 13.3${NC}"
echo "   Image: TrueNAS-13.3-RELEASE.iso"
echo "   URL: https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/"
if [ -f "truenas-core.iso" ]; then
    SIZE=$(ls -lh truenas-core.iso | awk '{print $5}')
    echo "   Status: ✓ Downloaded ($SIZE)"
else
    echo "   Status: Not downloaded"
    echo "   Downloading (700MB)..."
    START=$(date +%s)
    curl -L -o truenas-core.iso "https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/TrueNAS-13.3-RELEASE.iso" 2>&1 | grep -E "%" | tail -10
    END=$(date +%s)
    DURATION=$((END - START))
    SIZE=$(ls -lh truenas-core.iso | awk '{print $5}')
    echo -e "   ${GREEN}✓ Downloaded in ${DURATION}s ($SIZE)${NC}"
fi
echo ""

echo "======================================"
echo -e "${GREEN}Benchmark Complete${NC}"
echo ""
echo "Cached images:"
ls -lh freebsd*.qcow2 truenas*.iso 2>/dev/null | awk '{print "  " $9 " - " $5}'
echo ""
echo "To test VMs:"
echo "  ./qemu-freebsd.sh"
echo "  ./qemu-truenas-scale.sh"
echo "  ./qemu-truenas-core.sh"
