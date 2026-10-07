#!/bin/sh
#
# Simple Download Benchmark - TrueNAS Images Only
# Focuses on what we can actually test
#

set -e


echo "VM Image Download Benchmark"
echo "==========================="
echo ""
echo "Architecture: $(uname -m)"
echo "Date: $(date)"
echo ""

# TrueNAS SCALE
echo "1. TrueNAS SCALE 24.04.2"
echo "   URL: https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/TrueNAS-SCALE-24.04.2.2.iso"
if [ -f "truenas-scale.iso" ]; then
    SIZE=$(find truenas-scale.iso -maxdepth 0 -exec ls -lh {} \; | awk '{print $5}')
    echo "   Status: ✓ Cached ($SIZE)"
else
    echo "   Downloading (1.4GB)..."
    START=$(date +%s)
    curl -# -L -o truenas-scale.iso "https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/TrueNAS-SCALE-24.04.2.2.iso"
    END=$(date +%s)
    DURATION=$((END - START))
    SIZE=$(find truenas-scale.iso -maxdepth 0 -exec ls -lh {} \; | awk '{print $5}')
    SPEED=$(echo "scale=2; $(find truenas-scale.iso -maxdepth 0 -exec ls -l {} \; | awk '{print $5}') / $DURATION / 1024 / 1024" | bc)
    echo "   ✓ Downloaded in ${DURATION}s ($SIZE, ${SPEED} MB/s)"
fi
echo ""

# TrueNAS CORE
echo "2. TrueNAS CORE 13.3"
echo "   URL: https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/TrueNAS-13.3-RELEASE.iso"
if [ -f "truenas-core.iso" ]; then
    SIZE=$(find truenas-core.iso -maxdepth 0 -exec ls -lh {} \; | awk '{print $5}')
    echo "   Status: ✓ Cached ($SIZE)"
else
    echo "   Downloading (700MB)..."
    START=$(date +%s)
    curl -# -L -o truenas-core.iso "https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/TrueNAS-13.3-RELEASE.iso"
    END=$(date +%s)
    DURATION=$((END - START))
    SIZE=$(find truenas-core.iso -maxdepth 0 -exec ls -lh {} \; | awk '{print $5}')
    SPEED=$(echo "scale=2; $(find truenas-core.iso -maxdepth 0 -exec ls -l {} \; | awk '{print $5}') / $DURATION / 1024 / 1024" | bc)
    echo "   ✓ Downloaded in ${DURATION}s ($SIZE, ${SPEED} MB/s)"
fi
echo ""

echo "==========================="
echo "Benchmark Complete!"
echo ""
echo "Downloaded images:"
find . -maxdepth 1 -name 'truenas*.iso' -exec ls -lh {} \; 2>/dev/null | awk '{print "  " $9 " - " $5}'
echo ""
echo "To test:"
echo "  ./qemu-truenas-scale.sh"
echo "  ./qemu-truenas-core.sh"
