#!/bin/bash
#
# Build Arch ISO using Docker (no sudo needed!)
#

set -e

echo "=== Building Arch M-series ISO with Docker ==="

# Build Docker image
echo "Building Docker image..."
docker build --platform linux/arm64 \
    -f docker/Dockerfile.arch-builder \
    -t arch-m-series-builder .

# Run build in container
echo "Building ISO in container..."
docker run --platform linux/arm64 \
    --rm \
    -v $(pwd):/workspace \
    -w /workspace \
    arch-m-series-builder \
    /bin/bash -c '
set -e
cd /workspace

# Download Arch ARM rootfs
wget -c http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

# Create build directory
mkdir -p /tmp/arch-build
cd /tmp/arch-build
mkdir -p rootfs

# Extract
tar xzf /workspace/ArchLinuxARM-aarch64-latest.tar.gz -C rootfs

# Copy kernel config
cp /workspace/kernels/alpine-m-series.config rootfs/tmp/

# Build kernel in chroot
arch-chroot rootfs /bin/bash << "CHROOT"
set -e
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel git bc
cd /usr/src
git clone --depth 1 https://github.com/torvalds/linux.git
cd linux
cp /tmp/alpine-m-series.config .config
make olddefconfig
make -j16 Image modules
make modules_install
cp arch/arm64/boot/Image /boot/vmlinuz-m-series
CHROOT

# Create ISO
mksquashfs rootfs arch-rootfs.sfs
xorriso -as mkisofs -o /workspace/arch-m-series.iso arch-rootfs.sfs

echo "✓ Arch ISO built: /workspace/arch-m-series.iso"
'

echo "✓ Complete!"
ls -lh arch-m-series.iso
