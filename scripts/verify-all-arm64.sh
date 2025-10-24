#!/bin/bash
#
# VERIFY ALL VMs ARE ARM64
#

echo "=== VERIFYING ALL VMs ARE ARM64 ==="
echo ""

limactl list | grep Running | while read LINE; do
    VM=$(echo $LINE | awk '{print $1}')
    VMTYPE=$(echo $LINE | awk '{print $4}')
    ARCH=$(echo $LINE | awk '{print $5}')
    
    echo "[$VM]"
    echo "  Lima arch: $ARCH"
    echo "  VM type: $VMTYPE"
    
    # Get actual arch from inside VM
    REAL_ARCH=$(limactl shell $VM -- uname -m 2>/dev/null || echo "not accessible")
    echo "  Real arch: $REAL_ARCH"
    
    if [ "$ARCH" = "aarch64" ] && [ "$REAL_ARCH" = "aarch64" ]; then
        echo "  ✓ ARM64 VERIFIED"
    elif [ "$ARCH" = "aarch64" ]; then
        echo "  ⏳ ARM64 config, VM booting/inaccessible"
    else
        echo "  ❌ NOT ARM64 - $ARCH"
    fi
    echo ""
done

echo "=== SUMMARY ==="
echo "Total VMs: $(limactl list | grep Running | wc -l)"
echo "ARM64 VMs: $(limactl list | grep Running | grep aarch64 | wc -l)"
echo "x86_64 VMs: $(limactl list | grep Running | grep x86_64 | wc -l)"
