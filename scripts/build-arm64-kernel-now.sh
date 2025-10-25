#!/bin/bash
#
# ACTUALLY BUILD ARM64 KERNEL - For M-series Macs
# This is the REAL build, not a test
#

set -e

VM_NAME="kernel-build"

echo "=========================================="
echo "BUILDING ARM64 KERNEL FOR M-SERIES"
echo "=========================================="
date
echo ""

# Check VM is running
if ! limactl list | grep -q "$VM_NAME.*Running"; then
    echo "❌ VM not running. Start with: limactl start $VM_NAME"
    exit 1
fi

echo "✅ VM is running"
echo ""

# Check disk space
echo "=== Checking Disk Space ==="
limactl shell $VM_NAME -- df -h /
AVAIL=$(limactl shell $VM_NAME -- df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo "Available: ${AVAIL}GB"

if [ "$AVAIL" -lt 15 ]; then
    echo "⚠️  WARNING: Only ${AVAIL}GB available"
    echo "Kernel build needs ~15-20GB"
    echo "This is a minimal VM - build may fail if space runs out"
    echo "Continuing anyway..."
fi
echo ""

# Create build script for ARM64
cat > /tmp/build-arm64-kernel.sh << 'BUILDSCRIPT'
#!/bin/bash
set -ex

echo "=========================================="
echo "ARM64 KERNEL BUILD - STARTING"
echo "=========================================="
date

# Install build dependencies
echo "=== Installing Build Tools ==="
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential libncurses-dev bison flex \
    libssl-dev libelf-dev bc git kmod \
    wget curl ca-certificates \
    dwarves pahole rsync cpio \
    zstd lz4

echo ""
echo "=== Checking System ==="
uname -a
nproc
df -h /usr/src
df -h /

echo ""
echo "=== Getting Kernel Source ==="
cd /usr/src

# Use Ubuntu's kernel source (already compatible)
KVER=$(uname -r | sed 's/-generic//')
echo "Current kernel: $(uname -r)"
echo "Installing source for: $KVER"

if [ ! -d linux ]; then
    echo "Installing Ubuntu kernel source..."
    sudo apt-get install -y linux-source
    
    # Extract the source
    cd /usr/src
    TARBALL=$(ls -t linux-source-*.tar.bz2 | head -1)
    echo "Extracting: $TARBALL"
    sudo tar xjf $TARBALL
    
    # Create symlink
    SRCDIR=$(ls -td linux-source-*/ | head -1)
    sudo ln -sf $SRCDIR linux
    sudo chown -R $USER:$USER linux $SRCDIR
else
    echo "Kernel source already exists"
fi

cd /usr/src/linux

echo ""
echo "=== Configuring for ARM64 ==="
# Start with ARM64 defconfig
make ARCH=arm64 defconfig

# Enable critical ARM64 features
scripts/config --enable ARM64
scripts/config --enable ARM64_VA_BITS_48
scripts/config --enable ARM64_PAGE_SHIFT_12
scripts/config --enable ARM64_4K_PAGES
scripts/config --enable ARM64_CRYPTO
scripts/config --enable CRYPTO_SHA256_ARM64
scripts/config --enable CRYPTO_AES_ARM64_CE
scripts/config --enable CRYPTO_CRC32_ARM64_CE
scripts/config --enable CRYPTO_GHASH_ARM64_CE

# Virtualization support (for Lima/QEMU/vfkit)
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI
scripts/config --enable VIRTIO_BLK
scripts/config --enable VIRTIO_NET
scripts/config --enable VIRTIO_CONSOLE
scripts/config --enable VIRTIO_BALLOON

# Storage
scripts/config --enable BLK_DEV_NVME
scripts/config --enable NVME_CORE
scripts/config --enable SCSI_VIRTIO

# Network
scripts/config --enable NETDEVICES
scripts/config --enable NET_CORE
scripts/config --enable ETHERNET

# File systems
scripts/config --enable EXT4_FS
scripts/config --enable BTRFS_FS
scripts/config --enable XFS_FS

# Apply config
make ARCH=arm64 olddefconfig

echo ""
echo "=== Building Kernel ==="
echo "This will take 20-40 minutes on ARM64..."
NCPU=$(nproc)
echo "Using $NCPU CPU cores"
echo "Start time: $(date)"

# Build with all cores
time make ARCH=arm64 -j$NCPU Image modules 2>&1 | tee /tmp/kernel-build.log

echo ""
echo "=== Installing Modules ==="
sudo make ARCH=arm64 modules_install

echo ""
echo "=== Installing Kernel ==="
KVER=$(make kernelrelease)
echo "Kernel version: $KVER"

# Install kernel image
sudo cp arch/arm64/boot/Image /boot/vmlinuz-${KVER}-m-series
sudo cp System.map /boot/System.map-${KVER}
sudo cp .config /boot/config-${KVER}

# Create symlinks
sudo ln -sf vmlinuz-${KVER}-m-series /boot/vmlinuz-m-series
sudo ln -sf System.map-${KVER} /boot/System.map-m-series
sudo ln -sf config-${KVER} /boot/config-m-series

echo ""
echo "=== Creating initramfs ==="
if command -v update-initramfs >/dev/null 2>&1; then
    sudo update-initramfs -c -k ${KVER}
elif command -v mkinitramfs >/dev/null 2>&1; then
    sudo mkinitramfs -o /boot/initrd.img-${KVER} ${KVER}
fi

echo ""
echo "=== Updating Bootloader ==="
if command -v update-grub >/dev/null 2>&1; then
    sudo update-grub
elif [ -f /boot/grub/grub.cfg ]; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

echo ""
echo "=========================================="
echo "KERNEL BUILD COMPLETE ✅"
echo "=========================================="
date
echo ""
echo "Kernel: $KVER"
echo "Location: /boot/vmlinuz-${KVER}-m-series"
echo "Build log: /tmp/kernel-build.log"
echo ""
ls -lh /boot/vmlinuz-${KVER}-m-series
ls -lh /boot/System.map-${KVER}
ls -lh /boot/config-${KVER}
[ -f /boot/initrd.img-${KVER} ] && ls -lh /boot/initrd.img-${KVER}
echo ""
echo "To use this kernel:"
echo "  1. Reboot VM: sudo reboot"
echo "  2. Verify: uname -r"
BUILDSCRIPT

chmod +x /tmp/build-arm64-kernel.sh

echo "=== Copying Build Script to VM ==="
limactl copy /tmp/build-arm64-kernel.sh $VM_NAME:/tmp/

echo ""
echo "=========================================="
echo "STARTING KERNEL BUILD IN VM"
echo "=========================================="
echo ""
echo "This will take 20-40 minutes"
echo "Progress will be shown below"
echo ""
echo "Build started at: $(date)"
echo ""

# Run the build
if limactl shell $VM_NAME -- bash /tmp/build-arm64-kernel.sh; then
    echo ""
    echo "=========================================="
    echo "✅ KERNEL BUILD SUCCESSFUL!"
    echo "=========================================="
    echo ""
    echo "Build completed at: $(date)"
    echo ""
    echo "Kernel is installed in VM"
    echo "To verify:"
    echo "  limactl shell $VM_NAME -- ls -lh /boot/vmlinuz-*-m-series"
    echo ""
    echo "To reboot with new kernel:"
    echo "  limactl shell $VM_NAME -- sudo reboot"
    echo "  sleep 30"
    echo "  limactl shell $VM_NAME -- uname -r"
else
    echo ""
    echo "=========================================="
    echo "❌ KERNEL BUILD FAILED"
    echo "=========================================="
    echo ""
    echo "Check build log:"
    echo "  limactl shell $VM_NAME -- cat /tmp/kernel-build.log"
    echo "Check disk space:"
    echo "  limactl shell $VM_NAME -- df -h"
    exit 1
fi
