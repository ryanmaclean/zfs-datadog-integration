#!/bin/bash
#
# NetBSD 10.0 ARM64 using vfkit
# Minimal: 6GB disk, 2GB RAM, 2 CPUs
# NOTE: NetBSD has ZFS support (via OpenZFS port)
#

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
fi

VM_NAME="netbsd"
VM_DIR="${VM_STORAGE_DIR:-$HOME/.vfkit}/$VM_NAME"
DOWNLOAD_DIR="${DOWNLOAD_CACHE_DIR:-$HOME/.vfkit/downloads}"
DISK_SIZE="6G"  # Minimal for NetBSD
MEMORY="2048"   # 2GB in MB
CPUS=2

# Create directories
mkdir -p "$VM_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "=== Creating NetBSD 10.0 ARM64 VM ==="

# Download NetBSD 10.0 ARM64 install image (use cache)
if [ ! -f "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.qcow2" ]; then
  if [ ! -f "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.img" ]; then
    echo "Downloading NetBSD 10.0 ARM64 install image to cache..."
    echo "Cache location: $DOWNLOAD_DIR"
    
    # NetBSD ARM64 install image
    curl -L -o "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64-install.img.gz" \
      "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/evbarm-aarch64/binary/gzimg/arm64.img.gz"
    
    echo "Extracting image..."
    gunzip "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64-install.img.gz"
    mv "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64-install.img" "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.img"
  fi
  
  echo "Converting to QCOW2 format for vfkit..."
  qemu-img convert -f raw -O qcow2 \
    "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.img" \
    "$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.qcow2"
  
  echo "✓ NetBSD image cached and converted"
else
  echo "✓ Using cached NetBSD image: $DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.qcow2"
fi

# Create disk image (6GB virtual, lazy allocated)
if [ ! -f "$VM_DIR/disk.img" ]; then
  echo "Creating 6GB disk image at: $VM_DIR/disk.img"
  qemu-img create -f qcow2 "$VM_DIR/disk.img" "$DISK_SIZE"
  echo "✓ VM disk created"
fi

# Launch VM with vfkit
echo "Starting NetBSD VM with vfkit..."
echo "Disk: $DISK_SIZE (6GB virtual, ~3-4GB actual)"
echo "Memory: ${MEMORY}MB (2GB)"
echo "CPUs: $CPUS"
echo ""
echo "NetBSD has ZFS support via OpenZFS port!"
echo "After installation: pkg_add openzfs"
echo ""
echo "Installation will be interactive - follow NetBSD installer"
echo ""

vfkit \
  --cpus $CPUS \
  --memory $MEMORY \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$DOWNLOAD_DIR/netbsd-10.0-evbarm-aarch64.qcow2" \
  --device virtio-net,nat,mac=52:54:00:12:34:64 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "NetBSD VM started!"
echo "Console log: $VM_DIR/console.log"
echo ""
echo "After installation, install ZFS:"
echo "  pkg_add openzfs"
echo "  echo 'zfs=YES' >> /etc/rc.conf"
echo "  service zfs start"
