#!/bin/bash
#
# COMPLETE ALL KERNELS - Install what's compiled, verify what works
#

set -e

echo "=== COMPLETING ALL KERNEL BUILDS ==="

# Check and install compiled kernels
for VM in debian-zfs ubuntu-zfs rocky-zfs; do
    echo ""
    echo "=== $VM ==="
    
    # Check if kernel compiled
    if limactl shell $VM -- test -f /usr/src/linux/arch/arm64/boot/Image 2>/dev/null; then
        echo "✓ Kernel compiled! Installing..."
        
        limactl shell $VM -- sudo bash -c '
            cd /usr/src/linux
            make modules_install
            cp arch/arm64/boot/Image /boot/vmlinuz-m-series
            cp System.map /boot/System.map-m-series
            cp .config /boot/config-m-series
            
            # Update bootloader
            if command -v update-grub >/dev/null 2>&1; then
                update-grub
            elif command -v grub2-mkconfig >/dev/null 2>&1; then
                grub2-mkconfig -o /boot/grub2/grub.cfg
            fi
            
            ls -lh /boot/vmlinuz-m-series
            echo "KERNEL INSTALLED"
        ' && echo "✓ [$VM] Kernel installed" || echo "❌ [$VM] Install failed"
        
    else
        echo "⏳ Still compiling or failed"
        # Check if build process is running
        limactl shell $VM -- ps aux | grep make | grep -v grep || echo "Build may have failed"
    fi
done

# FreeBSD
echo ""
echo "=== FreeBSD ==="
if limactl shell freebsd-build -- test -f /boot/kernel/kernel 2>/dev/null; then
    echo "✓ FreeBSD kernel exists"
else
    echo "⏳ FreeBSD still building or needs start"
fi

echo ""
echo "=== SUMMARY ==="
echo "Checking all VMs for kernels..."

for VM in zfs-test debian-zfs ubuntu-zfs rocky-zfs; do
    KERNEL=$(limactl shell $VM -- ls -lh /boot/vmlinuz-m-series 2>/dev/null | awk '{print $5}')
    if [ -n "$KERNEL" ]; then
        echo "✓ $VM: $KERNEL"
    else
        echo "❌ $VM: No kernel"
    fi
done

echo ""
echo "FreeBSD:"
limactl shell freebsd-build -- ls -lh /boot/kernel/kernel 2>/dev/null || echo "❌ No kernel"
