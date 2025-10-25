#!/bin/bash
#
# Configuration loader for vfkit VMs
# Sources .env if it exists, otherwise uses defaults
#

# Default configuration
DEFAULT_VM_STORAGE_DIR="$HOME/.vfkit"
DEFAULT_DOWNLOAD_CACHE_DIR="$HOME/.vfkit/downloads"
DEFAULT_MIN_FREE_SPACE_GB=20
DEFAULT_WARN_FREE_SPACE_GB=50

# Load .env if it exists
if [ -f "$(dirname "$0")/../.env" ]; then
    source "$(dirname "$0")/../.env"
    echo "✓ Loaded configuration from .env"
elif [ -f "$HOME/.vfkit.env" ]; then
    source "$HOME/.vfkit.env"
    echo "✓ Loaded configuration from ~/.vfkit.env"
fi

# Set defaults if not configured
export VM_STORAGE_DIR="${VM_STORAGE_DIR:-$DEFAULT_VM_STORAGE_DIR}"
export DOWNLOAD_CACHE_DIR="${DOWNLOAD_CACHE_DIR:-$DEFAULT_DOWNLOAD_CACHE_DIR}"
export MIN_FREE_SPACE_GB="${MIN_FREE_SPACE_GB:-$DEFAULT_MIN_FREE_SPACE_GB}"
export WARN_FREE_SPACE_GB="${WARN_FREE_SPACE_GB:-$DEFAULT_WARN_FREE_SPACE_GB}"

# Auto-mount remote storage if configured
if [ "$AUTO_MOUNT_REMOTE" = "true" ] && [ -n "$REMOTE_ZFS_SERVER" ]; then
    if [ ! -d "$REMOTE_ZFS_MOUNT" ]; then
        echo "Creating mount point: $REMOTE_ZFS_MOUNT"
        sudo mkdir -p "$REMOTE_ZFS_MOUNT"
    fi
    
    if ! mount | grep -q "$REMOTE_ZFS_MOUNT"; then
        echo "Mounting remote ZFS: $REMOTE_ZFS_SERVER:$REMOTE_ZFS_PATH"
        sudo mount -t nfs "$REMOTE_ZFS_SERVER:$REMOTE_ZFS_PATH" "$REMOTE_ZFS_MOUNT"
    fi
fi

# Create directories if they don't exist
mkdir -p "$VM_STORAGE_DIR"
mkdir -p "$DOWNLOAD_CACHE_DIR"

# Check disk space
check_disk_space() {
    local path="$1"
    local available_gb=$(df -BG "$path" | tail -1 | awk '{print $4}' | sed 's/G//')
    
    if [ "$available_gb" -lt "$MIN_FREE_SPACE_GB" ]; then
        echo "❌ ERROR: Only ${available_gb}GB free on $path"
        echo "   Minimum required: ${MIN_FREE_SPACE_GB}GB"
        echo "   Consider using remote storage (see .env.example)"
        return 1
    elif [ "$available_gb" -lt "$WARN_FREE_SPACE_GB" ]; then
        echo "⚠️  WARNING: Only ${available_gb}GB free on $path"
        echo "   Recommended: ${WARN_FREE_SPACE_GB}GB+"
    else
        echo "✓ Disk space OK: ${available_gb}GB available on $path"
    fi
    return 0
}

# Display configuration
echo ""
echo "=== VM Storage Configuration ==="
echo "VM Storage:     $VM_STORAGE_DIR"
echo "Download Cache: $DOWNLOAD_CACHE_DIR"
echo ""

# Check disk space
check_disk_space "$VM_STORAGE_DIR" || exit 1
check_disk_space "$DOWNLOAD_CACHE_DIR" || exit 1

echo ""
