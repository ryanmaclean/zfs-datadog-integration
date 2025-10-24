#!/bin/sh
#
# Build custom Alpine Linux kernel optimized for M-series
# Run inside Alpine ARM64 VM
#

set -e

echo "=== Building M-series Optimized Alpine Kernel ==="

# Install build dependencies
apk add alpine-sdk build-base bc bison flex openssl-dev \
        linux-headers ncurses-dev elfutils-dev bash \
        linux-firmware-none perl xz findutils

# Get kernel source
cd /usr/src
if [ ! -d "linux-virt" ]; then
    apk fetch --stdout linux-virt | tar -xz
fi

# Find kernel source directory
KDIR=$(find /usr/src -maxdepth 1 -name "linux-*" -type d | head -1)
cd "$KDIR"

echo "Building in: $KDIR"

# Copy our M-series config
cp /tmp/alpine-m-series.config .config

# Apply M-series specific optimizations
cat >> .config << 'EOF'

# M-series Compiler optimizations
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y
CONFIG_ARCH_SUPPORTS_ATOMIC_RMW=y

# Additional crypto
CONFIG_CRYPTO_CHACHA20_NEON=y
CONFIG_CRYPTO_NHPOLY1305_NEON=y

# Additional M-series features
CONFIG_ARM64_SVE=y  # Scalable Vector Extension (M2+)
CONFIG_ARM64_MTE=y  # Memory Tagging Extension (M2+)
EOF

# Configure kernel
make ARCH=arm64 olddefconfig

# Optimize compile flags for M-series
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export KCFLAGS="-march=armv8.4-a+crypto+crc+fp+simd -mtune=cortex-a76 -O3"
export KCPPFLAGS="-march=armv8.4-a+crypto+crc+fp+simd -mtune=cortex-a76 -O3"

# Build kernel (use all cores)
NCPUS=$(nproc)
echo "Building with $NCPUS cores..."

make -j"$NCPUS" Image.gz modules

# Install
make modules_install
cp arch/arm64/boot/Image.gz /boot/vmlinuz-m-series
cp System.map /boot/System.map-m-series
cp .config /boot/config-m-series

# Update bootloader
echo "Updating bootloader..."
apk add mkinitfs

# Create initramfs
mkinitfs -o /boot/initramfs-m-series $(make kernelrelease)

# Update extlinux config
cat > /boot/extlinux/extlinux.conf << EOF
DEFAULT m-series
TIMEOUT 30
PROMPT 1

LABEL m-series
    MENU LABEL M-series Optimized Kernel
    LINUX /boot/vmlinuz-m-series
    INITRD /boot/initramfs-m-series
    APPEND root=/dev/vda3 modules=ext4 quiet rootfstype=ext4
EOF

echo ""
echo "✓ M-series optimized kernel built!"
echo ""
echo "Kernel: /boot/vmlinuz-m-series"
echo "Config: /boot/config-m-series"
echo ""
echo "Optimizations enabled:"
echo "  - ARMv8.4-A instruction set"
echo "  - Hardware crypto (AES, SHA, CRC32)"
echo "  - NEON SIMD"
echo "  - 16K pages (unified memory optimized)"
echo "  - Huge pages for ZFS ARC"
echo "  - NVMe-only storage stack"
echo "  - No legacy drivers"
echo ""
echo "Reboot to use new kernel"
