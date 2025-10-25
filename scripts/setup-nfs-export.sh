#!/bin/bash
#
# Setup NFS export on i9-zfs-pop.local for tank3
# Run this ON the remote server
#

set -e

echo "=== Setting up NFS export for tank3 ==="

# Enable NFS sharing on ZFS
echo "Enabling NFS share on tank3..."
sudo zfs set sharenfs="rw,no_subtree_check,no_root_squash" tank3

# Verify
echo ""
echo "Current NFS settings:"
zfs get sharenfs tank3

# Restart NFS server
echo ""
echo "Restarting NFS server..."
sudo systemctl restart nfs-server
sudo systemctl status nfs-server --no-pager | head -10

# Show exports
echo ""
echo "Current NFS exports:"
sudo exportfs -v

echo ""
echo "✓ NFS export configured!"
echo ""
echo "On Mac, mount with:"
echo "  sudo mount -t nfs i9-zfs-pop.local:/tank3 /Volumes/tank3"
