#!/bin/sh
#
# Build minimal FreeBSD for ZFS testing on M-series
# Creates a ~200MB root with ONLY ZFS + networking + SSH
#

set -e

OUTDIR="${OUTDIR:-/tmp/freebsd-minimal}"
VERSION="14.0"

echo "=== Building ZFS-Minimal FreeBSD for M-series ==="
echo "Output: $OUTDIR"

# This needs to run on FreeBSD
if [ "$(uname -s)" != "FreeBSD" ]; then
    echo "Error: Must run on FreeBSD"
    echo "Run this script inside FreeBSD VM"
    exit 1
fi

mkdir -p "$OUTDIR"

# Download minimal FreeBSD base
cd "$OUTDIR"
fetch https://download.freebsd.org/releases/arm64/aarch64/$VERSION-RELEASE/base.txz

# Extract to rootfs
mkdir -p rootfs
tar -xf base.txz -C rootfs

# Remove unnecessary files
echo "Trimming unnecessary files..."
rm -rf rootfs/usr/share/man/*
rm -rf rootfs/usr/share/doc/*
rm -rf rootfs/usr/share/examples/*
rm -rf rootfs/usr/share/locale/*
rm -rf rootfs/usr/share/misc/*
rm -rf rootfs/usr/tests/*
rm -rf rootfs/usr/lib32/*  # No 32-bit support needed
rm -rf rootfs/boot/kernel/*.symbols

# Configure system
cat > rootfs/etc/rc.conf << 'EOF'
hostname="zfs-minimal"
ifconfig_DEFAULT="DHCP inet6 accept_rtadv"
sshd_enable="YES"
zfs_enable="YES"
sendmail_enable="NONE"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
dumpdev="NO"
EOF

# M-series optimizations
cat > rootfs/boot/loader.conf << 'EOF'
# M-series FreeBSD optimizations
hw.ncpu=16
kern.smp.maxcpus=16

# ZFS tuning
vfs.zfs.arc_max=8589934592
vfs.zfs.arc_min=2147483648
vfs.zfs.txg.timeout=5

# Network
kern.ipc.maxsockbuf=16777216
net.inet.tcp.sendspace=262144
net.inet.tcp.recvspace=262144

# Boot faster
autoboot_delay=1
beastie_disable="YES"
EOF

# Minimal fstab
cat > rootfs/etc/fstab << 'EOF'
/dev/gpt/rootfs    /    ufs    rw    1    1
tmpfs              /tmp tmpfs  rw,mode=1777 0 0
EOF

# Set root password
chroot rootfs /bin/sh -c 'echo "zfs" | pw usermod root -h 0'

# SSH config
sed -i '' 's/#PermitRootLogin.*/PermitRootLogin yes/' rootfs/etc/ssh/sshd_config

# Sysctl tuning
cat > rootfs/etc/sysctl.conf << 'EOF'
# M-series optimizations
kern.maxvnodes=262144
vm.v_free_min=65536
vm.v_free_target=131072

# Network
net.inet.tcp.recvbuf_max=16777216
net.inet.tcp.sendbuf_max=16777216
EOF

echo "Creating disk image..."
# Create 1GB sparse image
truncate -s 1G freebsd-minimal.img

# Attach as memory disk
mddev=$(mdconfig -a -t vnode -f freebsd-minimal.img)

# Partition
gpart create -s gpt $mddev
gpart add -t freebsd-boot -s 512K $mddev
gpart add -t freebsd-ufs -l rootfs $mddev

# Format
newfs -U /dev/${mddev}p2

# Mount and copy
mkdir -p mnt
mount /dev/${mddev}p2 mnt
cp -a rootfs/* mnt/
umount mnt

# Install bootloader
gpart bootcode -b rootfs/boot/pmbr -p rootfs/boot/gptboot -i 1 $mddev

# Detach
mdconfig -d -u $mddev

echo ""
echo "✓ ZFS-Minimal FreeBSD built!"
echo ""
echo "Image: $OUTDIR/freebsd-minimal.img"
echo "Size: $(du -h $OUTDIR/freebsd-minimal.img | cut -f1)"
echo ""
echo "Includes:"
echo "  - FreeBSD base"
echo "  - Native ZFS"
echo "  - SSH server"
echo "  - Networking"
echo ""
echo "Excludes:"
echo "  - Package manager (pkg)"
echo "  - Compiler"
echo "  - Documentation"
echo "  - Examples"
echo "  - Tests"
echo "  - 32-bit support"
echo ""
echo "Default login: root / zfs"
echo ""
echo "Use with Lima or QEMU"
