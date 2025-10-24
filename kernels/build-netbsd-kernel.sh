#!/bin/sh
#
# Build custom NetBSD kernel optimized for M-series
# Run inside NetBSD ARM64 VM
#

set -e

echo "=== Building M-series Optimized NetBSD Kernel ==="

# Install build tools
pkgin -y update
pkgin -y install git

# Get NetBSD source if not present
if [ ! -d "/usr/src" ]; then
    echo "Fetching NetBSD source..."
    cd /usr
    ftp https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/source/sets/src.tgz
    ftp https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/source/sets/syssrc.tgz
    tar -xzf src.tgz
    tar -xzf syssrc.tgz
    rm src.tgz syssrc.tgz
fi

# Copy our kernel config
cp /tmp/netbsd-m-series-kernel.conf /usr/src/sys/arch/evbarm/conf/M-SERIES

# Build kernel
cd /usr/src
echo "Building kernel (this will take 30-60 minutes)..."

# NetBSD uses build.sh
./build.sh -U -u -j$(sysctl -n hw.ncpu) kernel=M-SERIES

# Install kernel
echo "Installing kernel..."
KERNEL=$(find /usr/src/sys/arch/evbarm/compile/M-SERIES -name "netbsd" | head -1)
if [ -f "$KERNEL" ]; then
    cp "$KERNEL" /netbsd.m-series
    cp /netbsd /netbsd.old
    cp /netbsd.m-series /netbsd
else
    echo "Error: Kernel not found!"
    exit 1
fi

# Create optimized sysctl.conf
cat >> /etc/sysctl.conf << 'EOF'

# M-series optimizations
kern.maxvnodes=262144
kern.somaxkva=268435456
kern.ipc.maxsockbuf=16777216

# Virtual memory for unified memory
vm.anonmax=95
vm.filemax=95
vm.execmax=95

# Network
net.inet.tcp.sendspace=262144
net.inet.tcp.recvspace=262144

# ZFS (if loaded)
# Module parameters go in /etc/modprobe.d/ or boot loader
EOF

echo ""
echo "✓ M-series optimized NetBSD kernel built!"
echo ""
echo "Kernel: /netbsd"
echo "Backup: /netbsd.old"
echo ""
echo "Optimizations enabled:"
echo "  - ARMv8.4-A support"
echo "  - NVMe-only storage"
echo "  - No legacy drivers"
echo "  - Unified memory tuning"
echo ""
echo "Reboot to use new kernel:"
echo "  shutdown -r now"
