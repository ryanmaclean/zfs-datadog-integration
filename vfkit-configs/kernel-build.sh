#!/bin/bash
#
# Kernel Build VM using vfkit
# 15GB disk, 4GB RAM, 4 CPUs
#

set -e

VM_NAME="kernel-build"
VM_DIR="$HOME/.vfkit/$VM_NAME"
DISK_SIZE="15G"  # Minimum for kernel build
MEMORY=4096  # 4GB in MB
CPUS=4

echo "=== Creating Kernel Build VM with vfkit ==="

# Create VM directory
mkdir -p "$VM_DIR"

# Download Debian ARM64 image if not exists
if [ ! -f "$VM_DIR/debian-12-arm64.qcow2" ]; then
  echo "Downloading Debian 12 ARM64 cloud image..."
  curl -L -o "$VM_DIR/debian-12-arm64.qcow2" \
    "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2"
fi

# Create disk image (15GB virtual, lazy allocated)
if [ ! -f "$VM_DIR/disk.img" ]; then
  echo "Creating 15GB disk image (sparse)..."
  qemu-img create -f qcow2 "$VM_DIR/disk.img" "$DISK_SIZE"
  
  # Copy base image to disk
  qemu-img convert -O qcow2 "$VM_DIR/debian-12-arm64.qcow2" "$VM_DIR/disk.img"
  qemu-img resize "$VM_DIR/disk.img" "$DISK_SIZE"
fi

# Create cloud-init config
cat > "$VM_DIR/user-data" << 'EOF'
#cloud-config
users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... # Add your SSH key

packages:
  - build-essential
  - libncurses-dev
  - bison
  - flex
  - libssl-dev
  - libelf-dev
  - bc
  - git
  - kmod
  - wget
  - curl
  - dwarves
  - pahole
  - rsync
  - cpio

runcmd:
  - echo "Kernel build tools installed" > /tmp/build-ready
  - df -h / > /tmp/disk-space
EOF

# Create meta-data
cat > "$VM_DIR/meta-data" << EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

# Create cloud-init ISO
if [ ! -f "$VM_DIR/cloud-init.iso" ]; then
  echo "Creating cloud-init ISO..."
  hdiutil makehybrid -o "$VM_DIR/cloud-init.iso" \
    -hfs -joliet -iso -default-volume-name cidata \
    "$VM_DIR/user-data" "$VM_DIR/meta-data"
fi

# Launch VM with vfkit
echo "Starting VM with vfkit..."
echo "Disk: $DISK_SIZE (15GB virtual, ~12-13GB actual during build)"
echo "Memory: $MEMORY"
echo "CPUs: $CPUS"

vfkit \
  --cpus $CPUS \
  --memory $MEMORY \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$VM_DIR/cloud-init.iso" \
  --device virtio-net,nat,mac=52:54:00:12:34:57 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "Kernel build VM started!"
echo "Console log: $VM_DIR/console.log"
echo "SSH: ssh debian@localhost -p 2222"
echo ""
echo "To build kernel:"
echo "  ssh debian@localhost -p 2222"
echo "  cd /usr/src"
echo "  git clone --depth 1 --branch linux-6.6.y https://github.com/torvalds/linux.git"
echo "  cd linux && make ARCH=arm64 defconfig && make ARCH=arm64 -j4"
