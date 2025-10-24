#!/bin/sh
#
# Build custom OpenBSD kernel optimized for M-series
# Run inside OpenBSD ARM64 VM
#

set -e

echo "=== Building M-series Optimized OpenBSD Kernel ==="

# Get OpenBSD source
if [ ! -d "/sys" ]; then
    echo "Fetching OpenBSD source..."
    cd /usr/src
    # OpenBSD 7.6 source
    ftp https://cdn.openbsd.org/pub/OpenBSD/7.6/sys.tar.gz
    tar -xzf sys.tar.gz
    rm sys.tar.gz
fi

# Copy our kernel config
cp /tmp/openbsd-m-series-kernel.conf /sys/arch/arm64/conf/M-SERIES

# Build kernel
cd /sys/arch/arm64/conf
config M-SERIES

cd ../compile/M-SERIES
echo "Building kernel (this will take 15-30 minutes)..."
make -j$(sysctl -n hw.ncpu)

# Install kernel
echo "Installing kernel..."
make install

# Create optimized sysctl.conf
cat >> /etc/sysctl.conf << 'EOF'

# M-series optimizations
kern.maxvnodes=262144
kern.somaxconn=1024
kern.seminfo.semmni=256
kern.seminfo.semmns=2048
kern.shminfo.shmmax=268435456

# Buffer cache for unified memory
kern.bufcachepercent=90

# Network
net.inet.ip.forwarding=1
net.inet6.ip6.forwarding=1
net.inet.tcp.sendspace=262144
net.inet.tcp.recvspace=262144
EOF

echo ""
echo "✓ M-series optimized OpenBSD kernel built!"
echo ""
echo "Kernel: /bsd"
echo "Backup: /bsd.old"
echo ""
echo "Optimizations enabled:"
echo "  - ARMv8.4-A support"
echo "  - NVMe-only storage"
echo "  - No legacy drivers"
echo "  - Buffer cache tuning"
echo ""
echo "Note: ZFS on OpenBSD is experimental"
echo "Build ZFS separately from ports if needed"
echo ""
echo "Reboot to use new kernel:"
echo "  shutdown -r now"
