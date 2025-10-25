#!/bin/bash
#
# OpenBSD 7.6 ARM64 using vfkit
# Minimal: 6GB disk, 2GB RAM, 2 CPUs
# NOTE: No ZFS (license incompatibility)
#

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
fi

VM_NAME="openbsd"
VM_DIR="${VM_STORAGE_DIR:-$HOME/.vfkit}/$VM_NAME"
DOWNLOAD_DIR="${DOWNLOAD_CACHE_DIR:-$HOME/.vfkit/downloads}"
DISK_SIZE="6G"  # Minimal for OpenBSD
MEMORY="2048"  # 2GB in MB
CPUS=2

# Create directories
mkdir -p "$VM_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "=== Creating OpenBSD 7.6 ARM64 VM ==="

# Create VM directory
mkdir -p "$VM_DIR"

# Download OpenBSD 7.6 ARM64 install image (use cache)
if [ ! -f "$DOWNLOAD_DIR/openbsd-7.6-install.img" ]; then
  echo "Downloading OpenBSD 7.6 ARM64 install image to cache..."
  echo "Cache location: $DOWNLOAD_DIR"
  curl -L -o "$DOWNLOAD_DIR/openbsd-7.6-install.img" \
    "https://cdn.openbsd.org/pub/OpenBSD/7.6/arm64/install76.img"
  echo "✓ OpenBSD image cached"
else
  echo "✓ Using cached OpenBSD image: $DOWNLOAD_DIR/openbsd-7.6-install.img"
fi

# Create disk image (6GB virtual, lazy allocated)
if [ ! -f "$VM_DIR/disk.img" ]; then
  echo "Creating 6GB disk image at: $VM_DIR/disk.img"
  qemu-img create -f qcow2 "$VM_DIR/disk.img" "$DISK_SIZE"
  echo "✓ VM disk created"
fi

# Launch VM with vfkit
echo "Starting OpenBSD VM with vfkit..."
echo "Disk: $DISK_SIZE (6GB virtual, ~3-4GB actual)"
echo "Memory: ${MEMORY}MB (2GB)"
echo "CPUs: $CPUS"
echo ""
echo "NOTE: OpenBSD does NOT support ZFS (license incompatibility)"
echo "      This is for general BSD testing only"
echo ""
echo "Installation will be interactive - follow OpenBSD installer"
echo ""

vfkit \
  --cpus $CPUS \
  --memory $MEMORY \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$DOWNLOAD_DIR/openbsd-7.6-install.img" \
  --device virtio-net,nat,mac=52:54:00:12:34:61 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "OpenBSD VM started!"
echo "Console log: $VM_DIR/console.log"
echo ""
echo "Follow the installer prompts to complete installation"
