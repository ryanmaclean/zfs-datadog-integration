#!/bin/bash
#
# Build M-series kernel LIVE in zfs-test VM
# Fixed version with proper error handling and disk space checks
#

set -e

echo "=== Building M-series Kernel LIVE ==="
date

VM="zfs-test"

# Pre-flight checks
echo "Checking VM status..."
if ! limactl list | grep -q "$VM.*Running"; then
  echo "ERROR: VM '$VM' is not running"
  echo "Start it with: limactl start $VM"
  exit 1
fi

echo "Checking disk space..."
AVAILABLE=$(limactl shell $VM -- df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE" -lt 20 ]; then
  echo "WARNING: Only ${AVAILABLE}GB available. Kernel build needs ~20GB"
  echo "Consider expanding VM disk or cleaning up space"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Create build script
cat > /tmp/build-m-kernel.sh << 'SCRIPT'
#!/bin/bash
set -ex

echo "=== Installing build tools ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential libncurses-dev bison flex \
  libssl-dev libelf-dev bc git kmod \
  wget curl ca-certificates \
  dwarves pahole rsync cpio

echo "=== Checking disk space ==="
df -h /usr/src
df -h /boot

echo "=== Getting kernel source ==="
cd /usr/src
if [ ! -d linux ]; then
  # Use stable 6.6 LTS instead of bleeding edge master
  echo "Cloning Linux 6.6 LTS kernel..."
  git clone --depth 1 --branch linux-6.6.y https://github.com/torvalds/linux.git
else
  echo "Kernel source already exists, updating..."
  cd linux
  git fetch --depth 1 origin linux-6.6.y
  git reset --hard FETCH_HEAD
fi
cd linux

echo "=== Configuring for ARM64 M-series ==="
# Start with ARM64 defconfig (not generic defconfig)
make ARCH=arm64 defconfig

# Enable critical ARM64 features
scripts/config --enable ARM64
scripts/config --enable ARM64_VA_BITS_48
scripts/config --enable ARM64_PAGE_SHIFT_12
scripts/config --enable ARM64_CRYPTO
scripts/config --enable CRYPTO_SHA256_ARM64
scripts/config --enable CRYPTO_AES_ARM64_CE
scripts/config --enable CRYPTO_CRC32_ARM64_CE
scripts/config --enable CRYPTO_GHASH_ARM64_CE

# Storage drivers
scripts/config --enable BLK_DEV_NVME
scripts/config --enable NVME_CORE
scripts/config --enable SCSI_VIRTIO

# Virtualization support (for Lima/QEMU)
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI
scripts/config --enable VIRTIO_BLK
scripts/config --enable VIRTIO_NET
scripts/config --enable VIRTIO_CONSOLE

# Network
scripts/config --enable NETDEVICES
scripts/config --enable NET_CORE
scripts/config --enable ETHERNET

# File systems
scripts/config --enable EXT4_FS
scripts/config --enable BTRFS_FS
scripts/config --enable XFS_FS

# ZFS support (if available - might need separate module)
scripts/config --module ZFS || echo "ZFS not in kernel tree (will need separate build)"

# Apply config
make ARCH=arm64 olddefconfig

echo "=== Building kernel (this takes 20-40 min on ARM64) ==="
# Use all available cores
NCPU=$(nproc)
echo "Building with $NCPU cores..."
make ARCH=arm64 -j$NCPU Image modules 2>&1 | tee /tmp/kernel-build.log

echo "=== Installing modules ==="
make ARCH=arm64 modules_install

echo "=== Installing kernel ==="
KVER=$(make kernelrelease)
echo "Kernel version: $KVER"

# Install kernel image
cp arch/arm64/boot/Image /boot/vmlinuz-${KVER}-m-series
cp System.map /boot/System.map-${KVER}
cp .config /boot/config-${KVER}

# Create symlinks
ln -sf vmlinuz-${KVER}-m-series /boot/vmlinuz-m-series
ln -sf System.map-${KVER} /boot/System.map-m-series
ln -sf config-${KVER} /boot/config-m-series

echo "=== Creating initramfs ==="
if command -v update-initramfs >/dev/null 2>&1; then
  update-initramfs -c -k ${KVER}
elif command -v mkinitramfs >/dev/null 2>&1; then
  mkinitramfs -o /boot/initrd.img-${KVER} ${KVER}
else
  echo "WARNING: No initramfs tool found, skipping"
fi

echo "=== Updating bootloader ==="
if command -v update-grub >/dev/null 2>&1; then
  update-grub
elif [ -f /boot/grub/grub.cfg ]; then
  grub-mkconfig -o /boot/grub/grub.cfg
else
  echo "WARNING: GRUB not found, you may need to configure boot manually"
fi

echo "=== DONE ==="
echo ""
echo "Installed kernel files:"
ls -lh /boot/vmlinuz-${KVER}-m-series
ls -lh /boot/System.map-${KVER}
ls -lh /boot/config-${KVER}
[ -f /boot/initrd.img-${KVER} ] && ls -lh /boot/initrd.img-${KVER}
echo ""
echo "Kernel version: $KVER"
echo "Build log: /tmp/kernel-build.log"
SCRIPT

chmod +x /tmp/build-m-kernel.sh

# Copy to VM and execute
echo "Copying build script to VM..."
limactl copy /tmp/build-m-kernel.sh $VM:/tmp/

echo ""
echo "Starting kernel build in VM..."
echo "This will take 20-40 minutes depending on CPU cores"
echo ""

# Execute with proper error handling
if limactl shell $VM -- sudo /tmp/build-m-kernel.sh; then
  echo ""
  echo "✅ Kernel build SUCCESSFUL!"
  echo ""
  echo "Kernel installed in VM. To use it:"
  echo "  1. Reboot VM: limactl shell $VM -- sudo reboot"
  echo "  2. Wait for reboot: sleep 10"
  echo "  3. Verify: limactl shell $VM -- uname -r"
  echo ""
  echo "Or run: ./scripts/reboot-with-new-kernel.sh"
else
  echo ""
  echo "❌ Kernel build FAILED"
  echo ""
  echo "Check build log:"
  echo "  limactl shell $VM -- cat /tmp/kernel-build.log"
  echo ""
  echo "Check disk space:"
  echo "  limactl shell $VM -- df -h"
  exit 1
fi
