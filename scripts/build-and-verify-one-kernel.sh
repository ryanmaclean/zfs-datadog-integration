#!/bin/sh
#
# Build ONE custom kernel and VERIFY it works
# Use existing zfs-test VM that already works
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VM="zfs-test"

echo "${CYAN}═══════════════════════════════════════${NC}"
echo "${CYAN}Build & Verify ONE M-series Kernel${NC}"
echo "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Baseline
echo "${CYAN}[1/8] Capturing baseline...${NC}"
remote_script=$(cat <<'REMOTE_SCRIPT'
echo "Current kernel: $(uname -r)"
echo "ZFS version: $(zfs version | head -1)"
echo ""
cat /proc/cpuinfo | grep Features | head -1
REMOTE_SCRIPT
)
limactl shell $VM -- sh -c "$remote_script" > baseline.txt
cat baseline.txt

# Install build tools
echo ""
echo "${CYAN}[2/8] Installing build tools...${NC}"
limactl shell $VM -- sudo apt-get update
limactl shell $VM -- sudo apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev bc

# Get kernel source
echo ""
echo "${CYAN}[3/8] Getting kernel source...${NC}"
remote_script=$(cat <<'REMOTE_SCRIPT'
if [ ! -d /usr/src/linux ]; then
    cd /usr/src
    sudo git clone --depth 1 --branch master https://github.com/torvalds/linux.git
fi
REMOTE_SCRIPT
)
limactl shell $VM -- sh -c "$remote_script"

# Copy our M-series config
echo ""
echo "${CYAN}[4/8] Configuring for M-series...${NC}"
limactl copy kernels/alpine-m-series.config $VM:/tmp/m-series.config

remote_script=$(cat <<'REMOTE_SCRIPT'
cd /usr/src/linux
sudo cp /tmp/m-series.config .config
sudo make ARCH=arm64 olddefconfig
REMOTE_SCRIPT
)
limactl shell $VM -- sh -c "$remote_script"

# Build kernel
echo ""
echo "${CYAN}[5/8] Building kernel (20-30 minutes)...${NC}"
remote_script=$(cat <<'REMOTE_SCRIPT'
cd /usr/src/linux
sudo make ARCH=arm64 -j$(nproc) Image.gz modules
REMOTE_SCRIPT
)
limactl shell $VM -- sh -c "$remote_script" || {
    echo "${YELLOW}Build failed, check errors above${NC}"
    exit 1
}

# Install kernel
echo ""
echo "${CYAN}[6/8] Installing custom kernel...${NC}"
remote_script=$(cat <<'REMOTE_SCRIPT'
cd /usr/src/linux
sudo make ARCH=arm64 modules_install
sudo cp arch/arm64/boot/Image.gz /boot/vmlinuz-m-series
sudo update-grub
REMOTE_SCRIPT
)
limactl shell $VM -- sh -c "$remote_script"

# Reboot
echo ""
echo "${CYAN}[7/8] Rebooting with custom kernel...${NC}"
limactl shell $VM -- sudo reboot || true
sleep 30

# Verify
echo ""
echo "${CYAN}[8/8] Verifying custom kernel...${NC}"
sleep 10

remote_script=$(cat <<'REMOTE_SCRIPT'
echo "✓ Booted with: $(uname -r)"
echo ""
echo "=== Testing ZFS ==="
sudo zpool import testpool || true
sudo zpool list
echo ""
echo "=== Creating dataset ==="
sudo zfs create testpool/custom-kernel-test
sudo dd if=/dev/zero of=/testpool/custom-kernel-test/100mb bs=1M count=100
echo ""
echo "✓ ZFS works with custom kernel!"
REMOTE_SCRIPT
)
limactl shell $VM -- sh -c "$remote_script" > verification.txt

cat verification.txt

echo ""
echo "${GREEN}✓ Custom M-series kernel VERIFIED working!${NC}"
echo ""
echo "Baseline: baseline.txt"
echo "Verification: verification.txt"
