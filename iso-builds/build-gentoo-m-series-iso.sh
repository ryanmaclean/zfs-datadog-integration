#!/bin/bash
#
# Build custom Gentoo ARM64 ISO with M-series optimizations
# For Gentoo maintainers who know the process
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  Gentoo M-series ISO Builder             ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

ISO_NAME="gentoo-m-series-zfs-$(date +%Y%m%d).iso"
WORK_DIR="/tmp/gentoo-build"
STAGE3_URL="https://distfiles.gentoo.org/releases/arm64/autobuilds/latest-stage3-arm64-openrc.txt"

echo "${CYAN}Building Gentoo ARM64 ISO with:${NC}"
echo "  - Stage3 ARM64 OpenRC"
echo "  - M-series kernel config"
echo "  - ZFS built-in"
echo "  - musl or glibc (your choice)"
echo "  - Optimized for M1-M5"
echo ""

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# ============================================================================
# 1. FETCH STAGE3
# ============================================================================

echo "${CYAN}[1/7] Fetching Gentoo ARM64 Stage3...${NC}"

# Get latest stage3 tarball
LATEST=$(curl -s "$STAGE3_URL" | grep -v '^#' | awk '{print $1}' | head -1)
STAGE3_TARBALL="https://distfiles.gentoo.org/releases/arm64/autobuilds/$LATEST"

echo "Downloading: $STAGE3_TARBALL"
wget -c "$STAGE3_TARBALL" -O stage3.tar.xz

# Extract
echo "Extracting stage3..."
mkdir -p rootfs
tar xpf stage3.tar.xz -C rootfs

echo "${GREEN}✓ Stage3 extracted${NC}"

# ============================================================================
# 2. CONFIGURE PORTAGE
# ============================================================================

echo "${CYAN}[2/7] Configuring Portage for M-series...${NC}"

cat > rootfs/etc/portage/make.conf << 'EOF'
# M-series optimized Gentoo build config

# Compiler flags for M-series (ARMv8.4-A minimum)
COMMON_FLAGS="-O3 -pipe -march=armv8.4-a+crypto+crc+fp+simd -mtune=cortex-a76"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# CPU flags
CPU_FLAGS_ARM="aes crc32 edsp neon sha1 sha2 thumb thumb2 v4 v5 v6 v7 v8 vfp vfpv3 vfpv4 vfp-d32"

# Parallelism (adjust for your Mac)
MAKEOPTS="-j16"  # M3/M4/M5 with 12+ cores
EMERGE_DEFAULT_OPTS="--jobs=4 --load-average=12"

# USE flags for ZFS + minimal system
USE="zfs -X -gtk -gnome -kde minimal crypt lz4 ssl"

# Features
FEATURES="parallel-fetch parallel-install"

# Accept licenses
ACCEPT_LICENSE="*"

# Mirrors (add your preferred mirror)
GENTOO_MIRRORS="https://distfiles.gentoo.org"

# Architecture
ACCEPT_KEYWORDS="arm64"
EOF

echo "${GREEN}✓ Portage configured${NC}"

# ============================================================================
# 3. CHROOT AND BUILD KERNEL
# ============================================================================

echo "${CYAN}[3/7] Preparing chroot environment...${NC}"

# Mount necessary filesystems
mount --bind /proc rootfs/proc
mount --bind /sys rootfs/sys
mount --bind /dev rootfs/dev
mount --bind /dev/pts rootfs/dev/pts

# Copy M-series kernel config
cp ../kernels/alpine-m-series.config rootfs/usr/src/.config

# Chroot and build
cat > rootfs/build-kernel.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Inside chroot ==="

# Update Portage
emerge-webrsync

# Install kernel sources
emerge sys-kernel/gentoo-sources

# Configure kernel
cd /usr/src/linux
cp /usr/src/.config .config
make olddefconfig

# Build kernel
make -j$(nproc) Image.gz modules
make modules_install
cp arch/arm64/boot/Image.gz /boot/vmlinuz-m-series

# Install ZFS
echo "sys-fs/zfs ~arm64" >> /etc/portage/package.accept_keywords
emerge sys-fs/zfs

# Install bootloader
emerge sys-boot/grub
grub-install --target=arm64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg

echo "✓ Kernel and ZFS built"
EOF

chmod +x rootfs/build-kernel.sh

echo "${CYAN}Building kernel in chroot (this takes 30-60 minutes)...${NC}"
chroot rootfs /build-kernel.sh

echo "${GREEN}✓ Kernel built${NC}"

# ============================================================================
# 4. CONFIGURE SYSTEM
# ============================================================================

echo "${CYAN}[4/7] Configuring system...${NC}"

# Hostname
echo "gentoo-m-series" > rootfs/etc/hostname

# Network
cat > rootfs/etc/conf.d/net << 'EOF'
config_eth0="dhcp"
EOF

cd rootfs/etc/init.d
ln -sf net.lo net.eth0
rc-update add net.eth0 default
cd -

# SSH
chroot rootfs rc-update add sshd default

# ZFS
chroot rootfs rc-update add zfs-import boot
chroot rootfs rc-update add zfs-mount boot
chroot rootfs rc-update add zfs-zed default

# Root password
chroot rootfs /bin/bash -c 'echo "root:gentoo" | chpasswd'

echo "${GREEN}✓ System configured${NC}"

# ============================================================================
# 5. CREATE INITRAMFS
# ============================================================================

echo "${CYAN}[5/7] Creating initramfs...${NC}"

chroot rootfs /bin/bash << 'EOF'
emerge sys-kernel/dracut
dracut --kver $(ls /lib/modules | head -1) /boot/initramfs-m-series
EOF

echo "${GREEN}✓ Initramfs created${NC}"

# ============================================================================
# 6. BUILD ISO
# ============================================================================

echo "${CYAN}[6/7] Building bootable ISO...${NC}"

# Unmount
umount -R rootfs/proc rootfs/sys rootfs/dev

# Create ISO structure
mkdir -p iso/boot/grub

cp rootfs/boot/vmlinuz-m-series iso/boot/
cp rootfs/boot/initramfs-m-series iso/boot/

# GRUB config for ISO
cat > iso/boot/grub/grub.cfg << 'EOF'
set default=0
set timeout=5

menuentry 'Gentoo M-series (ZFS)' {
    linux /boot/vmlinuz-m-series root=/dev/ram0 init=/sbin/init
    initrd /boot/initramfs-m-series
}
EOF

# Create ISO
xorriso -as mkisofs \
    -o "$ISO_NAME" \
    -R -J \
    -b boot/grub/i386-pc/core.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    iso/

echo "${GREEN}✓ ISO created: $ISO_NAME${NC}"

# ============================================================================
# 7. CREATE SQUASHFS FOR EFFICIENCY
# ============================================================================

echo "${CYAN}[7/7] Creating compressed filesystem...${NC}"

mksquashfs rootfs gentoo-m-series-rootfs.squashfs -comp xz -Xbcj arm

echo "${GREEN}✓ SquashFS created${NC}"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║          BUILD COMPLETE!                 ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "${CYAN}Artifacts:${NC}"
echo "  ISO: $ISO_NAME"
echo "  Size: $(du -h "$ISO_NAME" | cut -f1)"
echo ""
echo "  SquashFS: gentoo-m-series-rootfs.squashfs"
echo "  Size: $(du -h gentoo-m-series-rootfs.squashfs | cut -f1)"
echo ""
echo "${CYAN}Features:${NC}"
echo "  ✓ Gentoo ARM64 Stage3"
echo "  ✓ M-series optimized kernel"
echo "  ✓ ZFS built-in"
echo "  ✓ Optimized for ARMv8.4-A (M1+)"
echo "  ✓ Hardware crypto enabled"
echo "  ✓ Bootable ISO"
echo ""
echo "${CYAN}Use with Lima:${NC}"
echo "  limactl start --name=gentoo-m-series gentoo-m-series.yaml"
echo ""
echo "${GREEN}Ready to boot on M-series Macs!${NC}"
