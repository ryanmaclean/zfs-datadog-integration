#!/bin/bash
#
# TrueNAS CORE (FreeBSD-based) with ZFS using vfkit
# Minimal: 20GB disk, 8GB RAM, 4 CPUs (TrueNAS requirements)
#

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
fi

VM_NAME="truenas-core"
VM_DIR="${VM_STORAGE_DIR:-$HOME/.vfkit}/$VM_NAME"
DOWNLOAD_DIR="${DOWNLOAD_CACHE_DIR:-$HOME/.vfkit/downloads}"
DISK_SIZE="20G"  # TrueNAS minimum
MEMORY="8192"    # 8GB in MB (TrueNAS minimum)
CPUS=4

# Create directories
mkdir -p "$VM_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "=== Creating TrueNAS CORE VM ==="

# Create VM directory
mkdir -p "$VM_DIR"

# Download TrueNAS CORE ISO (use cache)
if [ ! -f "$DOWNLOAD_DIR/truenas-core-13.0.iso" ]; then
  echo "Downloading TrueNAS CORE 13.0 ISO to cache..."
  echo "Cache location: $DOWNLOAD_DIR"
  echo "NOTE: This is a large download (~800MB)"
  curl -L -o "$DOWNLOAD_DIR/truenas-core-13.0.iso" \
    "https://download.truenas.com/TrueNAS-13.0/STABLE/U6.2/x64/TrueNAS-13.0-U6.2.iso"
  echo "✓ TrueNAS CORE ISO cached"
else
  echo "✓ Using cached TrueNAS CORE ISO: $DOWNLOAD_DIR/truenas-core-13.0.iso"
fi

# Create main disk (20GB virtual, lazy allocated)
if [ ! -f "$VM_DIR/disk.img" ]; then
  echo "Creating 20GB main disk..."
  qemu-img create -f qcow2 "$VM_DIR/disk.img" "$DISK_SIZE"
fi

# Create ZFS pool disks (2x 4GB for mirror)
if [ ! -f "$VM_DIR/zfs-disk1.img" ]; then
  echo "Creating ZFS pool disks (2x 4GB mirror)..."
  qemu-img create -f qcow2 "$VM_DIR/zfs-disk1.img" 4G
  qemu-img create -f qcow2 "$VM_DIR/zfs-disk2.img" 4G
fi

# Launch VM with vfkit
echo "Starting TrueNAS CORE VM with vfkit..."
echo "Main disk: $DISK_SIZE (20GB virtual)"
echo "ZFS disks: 2x 4GB (for mirror pool)"
echo "Memory: ${MEMORY}MB (8GB - TrueNAS minimum)"
echo "CPUs: $CPUS"
echo ""
echo "TrueNAS CORE is FreeBSD-based with native ZFS"
echo "Web UI will be available at: http://localhost:8080"
echo ""
echo "Installation will be interactive - follow TrueNAS installer"
echo ""

vfkit \
  --cpus $CPUS \
  --memory $MEMORY \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$VM_DIR/zfs-disk1.img" \
  --device virtio-blk,path="$VM_DIR/zfs-disk2.img" \
  --device virtio-blk,path="$DOWNLOAD_DIR/truenas-core-13.0.iso" \
  --device virtio-net,nat,mac=52:54:00:12:34:63 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "TrueNAS CORE VM started!"
echo "Console log: $VM_DIR/console.log"
echo ""
echo "After installation:"
echo "  Web UI: http://truenas-ip:80"
echo "  Default credentials: admin / (set during install)"
echo "  Create ZFS pool from the 2x 4GB disks"
echo ""
echo "TrueNAS CORE = FreeBSD + Native ZFS + Web UI"
