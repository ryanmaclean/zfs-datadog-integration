#!/bin/sh
#
# Build custom FreeBSD kernel optimized for M-series
# Run inside FreeBSD ARM64 VM
#

set -e

echo "=== Building M-series Optimized FreeBSD Kernel ==="

# Install build tools
pkg install -y git

# Get FreeBSD source if not present
if [ ! -d "/usr/src" ]; then
    echo "Fetching FreeBSD source..."
    git clone --depth 1 --branch releng/14.0 https://git.freebsd.org/src.git /usr/src
fi

cd /usr/src

# Copy our kernel config
cp /tmp/freebsd-m-series-kernel.conf /usr/src/sys/arm64/conf/M-SERIES

# Build kernel
echo "Building kernel (this will take 20-40 minutes)..."
make -j$(sysctl -n hw.ncpu) KERNCONF=M-SERIES buildkernel

# Install kernel
echo "Installing kernel..."
make KERNCONF=M-SERIES installkernel

# Create optimized loader.conf
cat >> /boot/loader.conf << 'EOF'

# M-series optimizations
hw.ncpu=16
kern.smp.maxcpus=16

# Network tuning
kern.ipc.maxsockbuf=16777216
net.inet.tcp.sendspace=262144
net.inet.tcp.recvspace=262144
net.inet.tcp.sendbuf_max=16777216
net.inet.tcp.recvbuf_max=16777216

# ZFS ARC tuning for unified memory
vfs.zfs.arc_max=17179869184  # 16GB
vfs.zfs.arc_min=4294967296   # 4GB
vfs.zfs.arc.meta_limit=4294967296  # 4GB metadata

# ZFS performance
vfs.zfs.txg.timeout=5
vfs.zfs.vdev.async_write_active_min_dirty_percent=30
vfs.zfs.vdev.async_write_active_max_dirty_percent=60

# Hardware crypto
kern.crypto.accelerated=1

# Virtual memory for unified memory architecture
vm.v_free_min=65536
vm.v_free_target=131072
vm.v_free_reserved=32768
vm.v_page_count=4194304

# Disable unnecessary logging
kern.log_wakeups_per_second=0

# Better scheduler for asymmetric cores
kern.sched.steal_thresh=2
kern.sched.interact=30
EOF

# Create ZFS module config
mkdir -p /boot/loader.conf.d
cat > /boot/loader.conf.d/zfs-m-series.conf << 'EOF'
# ZFS module parameters for M-series

# Use hardware CRC32
vfs.zfs.zio.use_uma=1

# Prefetch
vfs.zfs.prefetch.disable=0
vfs.zfs.arc.max_prefetch_shift=4

# L2ARC - disable (unified memory is already fast)
vfs.zfs.l2arc.write_max=0

# Checksums - use hardware
vfs.zfs.fletcher_4_impl="scalar"

# Scrub/resilver speed
vfs.zfs.resilver_min_time_ms=1000
vfs.zfs.scrub_min_time_ms=1000
vfs.zfs.scan_vdev_limit=16777216

# Async destroy
vfs.zfs.async_block_max_blocks=100000
EOF

echo ""
echo "✓ M-series optimized FreeBSD kernel built!"
echo ""
echo "Optimizations enabled:"
echo "  - Native ZFS (built into kernel)"
echo "  - ARMv8.4-A instruction set"
echo "  - Hardware crypto support"
echo "  - Unified memory tuning"
echo "  - NVMe-only storage stack"
echo "  - Asymmetric CPU scheduler"
echo "  - 16GB ZFS ARC (adjust based on RAM)"
echo ""
echo "Reboot to use new kernel:"
echo "  shutdown -r now"
echo ""
echo "After reboot, verify:"
echo "  uname -a  # Should show M-SERIES kernel"
echo "  sysctl vfs.zfs.arc_max  # Should show 17179869184"
