#!/bin/bash
#
# FreeBSD 14.2 ARM64 with Native ZFS using vfkit
# Minimal: 8GB disk, 4GB RAM, 2 CPUs
#

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
fi

VM_NAME="freebsd-zfs"
VM_DIR="${VM_STORAGE_DIR:-$HOME/.vfkit}/$VM_NAME"
DOWNLOAD_DIR="${DOWNLOAD_CACHE_DIR:-$HOME/.vfkit/downloads}"
DISK_SIZE="8G"  # Minimal for FreeBSD + ZFS
MEMORY="4096"  # 4GB in MB
CPUS=2

# Create directories
mkdir -p "$VM_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "=== Creating FreeBSD ARM64 VM with Native ZFS ==="

# Create VM directory
mkdir -p "$VM_DIR"

# Download FreeBSD 14.2 ARM64 image if not exists (use cache)
if [ ! -f "$DOWNLOAD_DIR/freebsd-14.2-arm64.qcow2" ]; then
  echo "Downloading FreeBSD 14.2 ARM64 cloud image to cache..."
  echo "Cache location: $DOWNLOAD_DIR"
  curl -L -o "$DOWNLOAD_DIR/freebsd-14.2-arm64.qcow2.xz" \
    "https://download.freebsd.org/releases/VM-IMAGES/14.2-RELEASE/aarch64/Latest/FreeBSD-14.2-RELEASE-arm64-aarch64.qcow2.xz"
  
  echo "Extracting image..."
  xz -d "$DOWNLOAD_DIR/freebsd-14.2-arm64.qcow2.xz"
  echo "✓ FreeBSD image cached at: $DOWNLOAD_DIR/freebsd-14.2-arm64.qcow2"
else
  echo "✓ Using cached FreeBSD image: $DOWNLOAD_DIR/freebsd-14.2-arm64.qcow2"
fi

# Create disk image (8GB virtual, lazy allocated)
if [ ! -f "$VM_DIR/disk.img" ]; then
  echo "Creating 8GB disk image at: $VM_DIR/disk.img"
  qemu-img create -f qcow2 "$VM_DIR/disk.img" "$DISK_SIZE"
  
  # Copy FreeBSD image to disk
  echo "Copying FreeBSD image to VM disk..."
  qemu-img convert -O qcow2 "$DOWNLOAD_DIR/freebsd-14.2-arm64.qcow2" "$VM_DIR/disk.img"
  qemu-img resize "$VM_DIR/disk.img" "$DISK_SIZE"
  echo "✓ VM disk created"
fi

# Create cloud-init config for FreeBSD
cat > "$VM_DIR/user-data" << 'EOF'
#cloud-config
users:
  - name: freebsd
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/sh
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... # Add your SSH key

packages:
  - curl
  - bash
  - git

runcmd:
  - echo "=== FreeBSD ARM64 with Native ZFS ==="
  - zpool version
  - zfs version
  - mkdir -p /var/zfs
  - truncate -s 512M /var/zfs/testpool.img
  - zpool create -f testpool /var/zfs/testpool.img || true
  - zfs set compression=lz4 testpool || true
  - zfs create testpool/data || true
  - zpool status testpool
  - echo "FreeBSD ZFS ready" > /tmp/zfs-ready
EOF

# Create meta-data
cat > "$VM_DIR/meta-data" << EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

# Create cloud-init ISO (FreeBSD compatible)
if [ ! -f "$VM_DIR/cloud-init.iso" ]; then
  echo "Creating cloud-init ISO..."
  # FreeBSD cloud-init needs ISO9660 format
  hdiutil makehybrid -o "$VM_DIR/cloud-init.iso" \
    -iso -joliet -default-volume-name cidata \
    "$VM_DIR/user-data" "$VM_DIR/meta-data"
fi

# Launch VM with vfkit
echo "Starting FreeBSD VM with vfkit..."
echo "Disk: $DISK_SIZE (8GB virtual, ~4-5GB actual)"
echo "Memory: $MEMORY"
echo "CPUs: $CPUS"
echo ""
echo "FreeBSD has NATIVE ZFS built into the kernel!"
echo ""

vfkit \
  --cpus $CPUS \
  --memory $MEMORY \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$VM_DIR/cloud-init.iso" \
  --device virtio-net,nat,mac=52:54:00:12:34:60 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "FreeBSD VM started!"
echo "Console log: $VM_DIR/console.log"
echo ""
echo "ZFS is NATIVE in FreeBSD - no installation needed!"
echo "Test ZFS:"
echo "  zpool status testpool"
echo "  zfs list"
