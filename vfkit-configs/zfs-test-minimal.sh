#!/bin/bash
#
# Minimal ZFS Test VM using vfkit
# 4GB disk, 2GB RAM, 2 CPUs
#

set -e

VM_NAME="zfs-test"
VM_DIR="$HOME/.vfkit/$VM_NAME"
DISK_SIZE="4G"  # Minimal size
MEMORY="2G"
CPUS=2

echo "=== Creating Minimal ZFS VM with vfkit ==="

# Create VM directory
mkdir -p "$VM_DIR"

# Download Debian ARM64 image if not exists
if [ ! -f "$VM_DIR/debian-12-arm64.qcow2" ]; then
  echo "Downloading Debian 12 ARM64 cloud image..."
  curl -L -o "$VM_DIR/debian-12-arm64.qcow2" \
    "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2"
fi

# Create disk image (4GB virtual, lazy allocated)
if [ ! -f "$VM_DIR/disk.img" ]; then
  echo "Creating 4GB disk image (sparse)..."
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
  - zfsutils-linux
  - zfs-dkms
  - build-essential
  - linux-headers-generic
  - curl
  - jq

runcmd:
  - modprobe zfs || true
  - mkdir -p /zfs-disks
  - truncate -s 256M /zfs-disks/disk1.img
  - truncate -s 256M /zfs-disks/disk2.img
  - zpool create -f testpool mirror /zfs-disks/disk1.img /zfs-disks/disk2.img || true
  - zfs set compression=lz4 testpool || true
  - zfs set atime=off testpool || true
  - zfs set quota=200M testpool || true
  - echo "ZFS pool created" > /tmp/zfs-ready
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
echo "Disk: $DISK_SIZE (4GB virtual, ~2-3GB actual)"
echo "CPUs: $CPUS"

vfkit \
  --cpus $CPUS \
  --memory $MEMORY \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$VM_DIR/cloud-init.iso" \
  --device virtio-net,nat,mac=52:54:00:12:34:56 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "VM started!"
echo "Console log: $VM_DIR/console.log"
echo "SSH: ssh debian@localhost -p 2222"
