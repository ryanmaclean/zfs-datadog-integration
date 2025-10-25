#!/bin/bash
#
# Mount remote ZFS storage from i9-zfs-pop.local
# For dev environment only - saves local disk space
#

set -e

REMOTE_SERVER="i9-zfs-pop.local"
REMOTE_PATH="/tank3"
LOCAL_MOUNT="/Volumes/tank3"

echo "=== Mounting Remote ZFS Storage ==="
echo "Server: $REMOTE_SERVER"
echo "Remote path: $REMOTE_PATH"
echo "Local mount: $LOCAL_MOUNT"
echo ""

# Check if already mounted
if mount | grep -q "$LOCAL_MOUNT"; then
    echo "✓ Already mounted at $LOCAL_MOUNT"
    df -h "$LOCAL_MOUNT"
    exit 0
fi

# Create mount point
if [ ! -d "$LOCAL_MOUNT" ]; then
    echo "Creating mount point..."
    sudo mkdir -p "$LOCAL_MOUNT"
fi

# Mount via NFS
echo "Mounting $REMOTE_SERVER:$REMOTE_PATH..."
sudo mount -t nfs "$REMOTE_SERVER:$REMOTE_PATH" "$LOCAL_MOUNT"

# Verify
if mount | grep -q "$LOCAL_MOUNT"; then
    echo ""
    echo "✓ Successfully mounted!"
    echo ""
    df -h "$LOCAL_MOUNT"
    echo ""
    echo "ZFS pool info:"
    ssh "$REMOTE_SERVER" "zpool status tank3" || echo "(Could not get remote pool status)"
else
    echo "❌ Mount failed"
    exit 1
fi

echo ""
echo "Remote storage ready at: $LOCAL_MOUNT"
echo ""
echo "To unmount:"
echo "  sudo umount $LOCAL_MOUNT"
