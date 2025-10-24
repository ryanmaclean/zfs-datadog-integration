#!/bin/bash
#
# Build Gentoo ISO using Docker (no sudo needed!)
#

set -e

echo "=== Building Gentoo M-series ISO with Docker ==="

# Build Docker image
echo "Building Gentoo builder image..."
docker build --platform linux/arm64 \
    -f docker/Dockerfile.gentoo-builder \
    -t gentoo-m-series-builder .

# Run build in container
echo "Building ISO in container (this takes 2-3 hours)..."
docker run --platform linux/arm64 \
    --rm \
    -v $(pwd):/workspace \
    -w /workspace \
    gentoo-m-series-builder \
    /bin/bash -c '
set -e

echo "Building Gentoo with M-series optimizations..."
echo "CFLAGS: -march=armv8.4-a+crypto+crc+fp+simd -mtune=cortex-a76"

# Build kernel
cd /usr/src/linux
make defconfig
make -j16 Image modules
make modules_install
cp arch/arm64/boot/Image /boot/vmlinuz-m-series

# Build ZFS
emerge sys-fs/zfs

# Create ISO
cd /
mksquashfs / /workspace/gentoo-m-series.squashfs \
    -comp xz -Xbcj arm -b 1M \
    -e workspace tmp var/tmp

echo "✓ Gentoo SquashFS built"
'

echo "✓ Complete!"
ls -lh gentoo-m-series.squashfs
