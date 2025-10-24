#!/bin/bash
#
# Build custom Arch Linux ARM64 ISO with M-series optimizations
# Fast, rolling-release, optimized for Apple Silicon
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  Arch Linux ARM64 M-series ISO Builder  ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

ISO_NAME="arch-m-series-$(date +%Y%m%d).iso"
WORK_DIR="/tmp/arch-build"

# ============================================================================
# 1. DOWNLOAD ARCH ARM BASE
# ============================================================================

echo "${CYAN}[1/6] Downloading Arch Linux ARM base...${NC}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Get latest Arch ARM rootfs
ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
echo "Downloading from $ARCH_URL"
wget -c "$ARCH_URL" -O arch-arm64.tar.gz

# Extract
echo "Extracting..."
mkdir -p rootfs
tar xzf arch-arm64.tar.gz -C rootfs

echo "${GREEN}✓ Arch ARM base extracted${NC}"

# ============================================================================
# 2. CONFIGURE PACMAN FOR M-SERIES
# ============================================================================

echo "${CYAN}[2/6] Configuring for M-series...${NC}"

# Custom makepkg.conf for M-series
cat > rootfs/etc/makepkg.conf << 'EOF'
# M-series optimized Arch build config

# Compiler flags for M-series (ARMv8.4-A minimum)
CFLAGS="-march=armv8.4-a+crypto+crc+fp+simd -mtune=cortex-a76 -O3 -pipe -fstack-protector-strong"
CXXFLAGS="$CFLAGS"
LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

# Build options
BUILDENV=(!distcc color !ccache check !sign)
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)

# Parallel compilation
MAKEFLAGS="-j16"

# Compression
COMPRESSGZ=(pigz -c -f -n)
COMPRESSBZ2=(pbzip2 -c -f)
COMPRESSXZ=(xz -c -z -T 16 -)
COMPRESSZST=(zstd -c -z -q -T16 -)

# Package output
PKGEXT='.pkg.tar.zst'
EOF

# pacman.conf optimizations
cat >> rootfs/etc/pacman.conf << 'EOF'

# M-series optimizations
[options]
ParallelDownloads = 10
EOF

echo "${GREEN}✓ Pacman configured${NC}"

# ============================================================================
# 3. INSTALL M-SERIES KERNEL
# ============================================================================

echo "${CYAN}[3/6] Building M-series kernel...${NC}"

# Mount for chroot
mount --bind /proc rootfs/proc
mount --bind /sys rootfs/sys  
mount --bind /dev rootfs/dev

# Build kernel in chroot
cat > rootfs/build-kernel.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Inside Arch chroot ==="

# Initialize pacman
pacman-key --init
pacman-key --populate archlinuxarm

# Update system
pacman -Syu --noconfirm

# Install kernel build deps
pacman -S --noconfirm base-devel git bc inetutils kmod libelf pahole cpio perl tar xz

# Get kernel source
cd /usr/src
git clone --depth 1 https://github.com/torvalds/linux.git linux-m-series
cd linux-m-series

# Copy M-series config
cp /tmp/kernel-config .config
make olddefconfig

# Build
make -j16 Image.gz modules
make modules_install
cp arch/arm64/boot/Image.gz /boot/vmlinuz-m-series

# Generate initramfs
pacman -S --noconfirm mkinitcpio
mkinitcpio -k $(ls /lib/modules | head -1) -g /boot/initramfs-m-series.img

# Install ZFS
echo "[archzfs]" >> /etc/pacman.conf
echo "Server = https://archzfs.com/\$repo/\$arch" >> /etc/pacman.conf
pacman-key --recv-keys F75D9D76
pacman-key --lsign-key F75D9D76

pacman -Sy --noconfirm zfs-dkms zfs-utils

echo "✓ Kernel and ZFS built"
EOF

chmod +x rootfs/build-kernel.sh

# Copy kernel config
cp ../kernels/alpine-m-series.config rootfs/tmp/kernel-config

echo "Building kernel in chroot (20-30 minutes)..."
chroot rootfs /build-kernel.sh

echo "${GREEN}✓ Kernel built${NC}"

# ============================================================================
# 4. CONFIGURE SYSTEM
# ============================================================================

echo "${CYAN}[4/6] Configuring system...${NC}"

# Hostname
echo "arch-m-series" > rootfs/etc/hostname

# Network
cat > rootfs/etc/systemd/network/20-wired.network << 'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
EOF

chroot rootfs systemctl enable systemd-networkd
chroot rootfs systemctl enable systemd-resolved

# SSH
chroot rootfs pacman -S --noconfirm openssh
chroot rootfs systemctl enable sshd

# ZFS services
chroot rootfs systemctl enable zfs-import-cache
chroot rootfs systemctl enable zfs-import.target
chroot rootfs systemctl enable zfs-mount
chroot rootfs systemctl enable zfs.target

# Root password
chroot rootfs /bin/bash -c 'echo "root:arch" | chpasswd'

# Cleanup
chroot rootfs pacman -Scc --noconfirm || true

echo "${GREEN}✓ System configured${NC}"

# ============================================================================
# 5. CREATE BOOTLOADER
# ============================================================================

echo "${CYAN}[5/6] Installing bootloader...${NC}"

chroot rootfs pacman -S --noconfirm grub efibootmgr

# GRUB config
cat > rootfs/boot/grub/grub.cfg << 'EOF'
set default=0
set timeout=3

menuentry 'Arch Linux M-series (ZFS)' {
    linux /boot/vmlinuz-m-series root=/dev/vda2 rw
    initrd /boot/initramfs-m-series.img
}
EOF

echo "${GREEN}✓ Bootloader configured${NC}"

# ============================================================================
# 6. BUILD ISO
# ============================================================================

echo "${CYAN}[6/6] Building ISO...${NC}"

# Unmount
umount -R rootfs/proc rootfs/sys rootfs/dev

# Create ISO filesystem
mkdir -p iso/boot
cp rootfs/boot/vmlinuz-m-series iso/boot/
cp rootfs/boot/initramfs-m-series.img iso/boot/
cp -r rootfs/boot/grub iso/boot/

# Create squashfs of rootfs
mksquashfs rootfs iso/arch-rootfs.sfs -comp xz -Xbcj arm -b 1M

# Build ISO
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "ARCH_M_SERIES" \
    -appid "Arch Linux ARM64 M-series" \
    -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -output "$ISO_NAME" \
    iso/

echo "${GREEN}✓ ISO created: $ISO_NAME${NC}"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║          BUILD COMPLETE!                 ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "${CYAN}Artifact:${NC} $ISO_NAME"
echo "${CYAN}Size:${NC} $(du -h "$ISO_NAME" | cut -f1)"
echo ""
echo "${CYAN}Features:${NC}"
echo "  ✓ Arch Linux ARM (rolling release)"
echo "  ✓ M-series optimized kernel"
echo "  ✓ ZFS + DKMS"
echo "  ✓ CFLAGS: -march=armv8.4-a+crypto -O3"
echo "  ✓ Parallel builds: -j16"
echo "  ✓ Bootable ISO with SquashFS"
echo ""
echo "${GREEN}Ready for Lima or bare metal M-series!${NC}"
