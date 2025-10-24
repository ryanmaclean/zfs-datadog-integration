#!/bin/bash
#
# Build M-series kernel LIVE in zfs-test VM
# No SSH issues - direct execution
#

set -e

echo "=== Building M-series Kernel LIVE ==="
date

VM="zfs-test"

# Create build script
cat > /tmp/build-m-kernel.sh << 'SCRIPT'
#!/bin/bash
set -ex

echo "=== Installing build tools ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential libncurses-dev bison flex \
  libssl-dev libelf-dev bc git kmod

echo "=== Getting kernel source ==="
cd /usr/src
if [ ! -d linux ]; then
  git clone --depth 1 --branch master https://github.com/torvalds/linux.git
fi
cd linux

echo "=== Configuring for M-series ==="
# Minimal M-series config
make defconfig
scripts/config --enable ARM64
scripts/config --enable ARM64_CRYPTO
scripts/config --enable CRYPTO_SHA256_ARM64
scripts/config --enable CRYPTO_AES_ARM64_CE
scripts/config --enable CRYPTO_CRC32_ARM64_CE
scripts/config --enable BLK_DEV_NVME
scripts/config --module ZFS

make olddefconfig

echo "=== Building kernel (this takes 20-30 min) ==="
make -j$(nproc) Image modules

echo "=== Installing kernel ==="
make modules_install
cp arch/arm64/boot/Image /boot/vmlinuz-m-series
cp System.map /boot/System.map-m-series
cp .config /boot/config-m-series

echo "=== Creating initramfs ==="
KVER=$(make kernelrelease)
update-initramfs -c -k $KVER

echo "=== Updating grub ==="
update-grub

echo "=== DONE ==="
ls -lh /boot/vmlinuz-m-series
SCRIPT

chmod +x /tmp/build-m-kernel.sh

# Copy to VM and execute
echo "Copying build script to VM..."
limactl copy /tmp/build-m-kernel.sh $VM:/tmp/

echo "Executing kernel build in VM..."
limactl shell $VM -- sudo /tmp/build-m-kernel.sh

echo ""
echo "✓ Kernel build complete!"
echo ""
echo "Next: Reboot VM with new kernel"
echo "  limactl shell $VM -- sudo reboot"
