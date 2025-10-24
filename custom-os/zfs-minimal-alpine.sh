#!/bin/sh
#
# Build minimal Alpine Linux for ZFS testing on M-series
# Creates a ~50MB root filesystem with ONLY ZFS + networking + SSH
#

set -e

OUTDIR="${OUTDIR:-/tmp/zfs-minimal}"
VERSION="3.19"

echo "=== Building ZFS-Minimal Alpine for M-series ==="
echo "Output: $OUTDIR"

# Create output directory
mkdir -p "$OUTDIR/rootfs"
cd "$OUTDIR"

# Bootstrap minimal Alpine
apk --arch aarch64 --root rootfs --initdb add alpine-base

# Install ONLY what we need
apk --arch aarch64 --root rootfs add \
    linux-virt \
    zfs \
    zfs-scripts \
    openssh \
    curl \
    bash \
    util-linux \
    e2fsprogs \
    ca-certificates

# Configure system
cat > rootfs/etc/fstab << 'EOF'
/dev/vda1    /       ext4    defaults,noatime    0 1
tmpfs        /tmp    tmpfs   defaults,noatime    0 0
EOF

# Network
cat > rootfs/etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Enable services
chroot rootfs /bin/sh << 'CHROOT'
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add hwdrivers sysinit

rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot
rc-update add networking boot

rc-update add zfs-import boot
rc-update add zfs-mount boot
rc-update add zfs-zed default

rc-update add sshd default
rc-update add local default

rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown
CHROOT

# Set hostname
echo "zfs-minimal" > rootfs/etc/hostname

# Set root password (change me!)
chroot rootfs /bin/sh -c 'echo "root:zfs" | chpasswd'

# SSH config - allow root login for testing
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' rootfs/etc/ssh/sshd_config

# M-series kernel parameters
cat > rootfs/etc/sysctl.d/m-series.conf << 'EOF'
# M-series optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=80
vm.dirty_background_ratio=20

# Network
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF

# ZFS module config
mkdir -p rootfs/etc/modprobe.d
cat > rootfs/etc/modprobe.d/zfs.conf << 'EOF'
# M-series ZFS tuning
options zfs zfs_arc_max=8589934592
options zfs zfs_arc_min=2147483648
options zfs zfs_prefetch_disable=0
options zfs zfs_txg_timeout=5
EOF

# Create initramfs
echo "Creating initramfs..."
mkinitfs -o "$OUTDIR/initramfs" \
    -F "base ext4 virtio scsi nvme network zfs" \
    $(chroot rootfs /bin/sh -c 'ls /lib/modules | head -1')

# Create bootable disk image
echo "Creating disk image..."
dd if=/dev/zero of=zfs-minimal.img bs=1M count=512
mkfs.ext4 -F zfs-minimal.img

# Mount and copy
mkdir -p mnt
mount -o loop zfs-minimal.img mnt
cp -a rootfs/* mnt/
umount mnt

echo ""
echo "✓ ZFS-Minimal Alpine built!"
echo ""
echo "Image: $OUTDIR/zfs-minimal.img"
echo "Size: $(du -h $OUTDIR/zfs-minimal.img | cut -f1)"
echo ""
echo "Root FS size: $(du -sh rootfs | cut -f1)"
echo ""
echo "Includes:"
echo "  - Linux virt kernel"
echo "  - ZFS + zed"
echo "  - SSH server"
echo "  - Networking"
echo "  - Minimal utilities"
echo ""
echo "Excludes:"
echo "  - Package manager (apk)"
echo "  - Compiler"
echo "  - Documentation"
echo "  - Man pages"
echo "  - Unnecessary drivers"
echo ""
echo "Default login: root / zfs"
echo ""
echo "Use with:"
echo "  qemu-system-aarch64 -M virt -cpu cortex-a76 \\"
echo "    -m 8G -smp 8 -drive file=zfs-minimal.img,format=raw"
