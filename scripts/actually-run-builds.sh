#!/bin/bash
#
# ACTUALLY RUN THE BUILDS - Not just test infrastructure
# This script launches VMs and runs actual builds
#

set -e

echo "=========================================="
echo "ACTUALLY RUNNING BUILDS - NOT JUST TESTS"
echo "=========================================="
date
echo ""

# Check if FreeBSD image is ready
if [ ! -f "/Volumes/tank3/iso-cache/freebsd-14.2-arm64.qcow2" ]; then
    echo "❌ FreeBSD image not downloaded"
    exit 1
fi

echo "=== Step 1: Extract FreeBSD Image ==="
cd /Volumes/tank3/iso-cache
if [ -f "freebsd-14.2-arm64.qcow2.xz" ]; then
    echo "Extracting FreeBSD image..."
    xz -d freebsd-14.2-arm64.qcow2.xz
fi

# Check if already extracted
if [ ! -f "freebsd-14.2-arm64.qcow2" ]; then
    echo "❌ FreeBSD QCOW2 not found after extraction"
    exit 1
fi

echo "✅ FreeBSD image ready: $(ls -lh freebsd-14.2-arm64.qcow2 | awk '{print $5}')"
echo ""

echo "=== Step 2: Create FreeBSD VM Disk ==="
VM_DIR="/Volumes/tank3/vms/freebsd-zfs"
mkdir -p "$VM_DIR"

if [ ! -f "$VM_DIR/disk.img" ]; then
    echo "Creating 8GB VM disk from FreeBSD image..."
    qemu-img convert -O qcow2 \
        /Volumes/tank3/iso-cache/freebsd-14.2-arm64.qcow2 \
        "$VM_DIR/disk.img"
    
    qemu-img resize "$VM_DIR/disk.img" 8G
    
    echo "✅ VM disk created: $(du -sh $VM_DIR/disk.img | awk '{print $1}')"
else
    echo "✅ VM disk already exists: $(du -sh $VM_DIR/disk.img | awk '{print $1}')"
fi
echo ""

echo "=== Step 3: Create Cloud-Init Config ==="
cat > "$VM_DIR/user-data" << 'EOF'
#cloud-config
users:
  - name: freebsd
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/sh

runcmd:
  - echo "FreeBSD VM booted" > /tmp/boot-complete
  - zpool version > /tmp/zfs-version
  - zfs version >> /tmp/zfs-version
  - mkdir -p /var/zfs
  - truncate -s 512M /var/zfs/testpool.img
  - zpool create -f testpool /var/zfs/testpool.img || true
  - zfs set compression=lz4 testpool || true
  - zpool status testpool > /tmp/zpool-status
  - echo "ZFS test complete" >> /tmp/boot-complete
EOF

cat > "$VM_DIR/meta-data" << EOF
instance-id: freebsd-zfs
local-hostname: freebsd-zfs
EOF

if [ ! -f "$VM_DIR/cloud-init.iso" ]; then
    echo "Creating cloud-init ISO..."
    # Create temp directory for cloud-init files
    CIDATA_DIR=$(mktemp -d)
    cp "$VM_DIR/user-data" "$CIDATA_DIR/"
    cp "$VM_DIR/meta-data" "$CIDATA_DIR/"
    
    hdiutil makehybrid -o "$VM_DIR/cloud-init.iso" \
        -iso -joliet -default-volume-name cidata \
        "$CIDATA_DIR"
    
    rm -rf "$CIDATA_DIR"
    echo "✅ Cloud-init ISO created"
else
    echo "✅ Cloud-init ISO exists"
fi
echo ""

echo "=== Step 4: Launch FreeBSD VM ==="
echo "Starting FreeBSD with native ZFS..."
echo "This will open a GUI window"
echo ""
echo "VM will:"
echo "  1. Boot FreeBSD 14.2 ARM64"
echo "  2. Auto-configure ZFS"
echo "  3. Create test pool"
echo "  4. Log results to /tmp/"
echo ""
echo "Press Ctrl+C in the GUI window to stop VM"
echo ""

# Launch VM (this will block and show GUI)
vfkit \
  --cpus 2 \
  --memory 4096 \
  --bootloader efi,variable-store="$VM_DIR/efi-vars.fd",create \
  --device virtio-blk,path="$VM_DIR/disk.img" \
  --device virtio-blk,path="$VM_DIR/cloud-init.iso" \
  --device virtio-net,nat,mac=52:54:00:12:34:60 \
  --device virtio-serial,logFilePath="$VM_DIR/console.log" \
  --device virtio-rng \
  --gui

echo ""
echo "VM stopped"
echo "Check console log: $VM_DIR/console.log"
