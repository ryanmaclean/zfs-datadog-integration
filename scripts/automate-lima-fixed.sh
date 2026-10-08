#!/usr/bin/env bash
# bash-required: BASH_SOURCE
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Lima VM Automated Testing ==="

# Ubuntu (already has pool)
echo "=== Testing ubuntu-zfs ==="
bash "$SCRIPT_DIR/automate-lima-complete.sh" --sealed-install ubuntu-zfs
limactl shell ubuntu-zfs sudo zpool scrub testpool
sleep 5
limactl shell ubuntu-zfs sudo zpool status testpool | grep scrub
echo "✓ ubuntu-zfs complete"

# Debian (load ZFS modules)
echo "=== Testing debian-zfs ==="
limactl shell debian-zfs sudo modprobe zfs
bash "$SCRIPT_DIR/automate-lima-complete.sh" --sealed-install debian-zfs
limactl shell debian-zfs 'sudo mkdir -p /tmp/zfs-test && sudo dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=256 && sudo dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=256 && sudo zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img'
limactl shell debian-zfs sudo zpool scrub testpool
sleep 5
limactl shell debian-zfs sudo zpool status testpool | grep scrub
echo "✓ debian-zfs complete"

echo "=== Lima Testing Complete ==="
echo "Ubuntu: ✓"
echo "Debian: ✓"
echo "Rocky: ✗ (ARM64 ZFS not available)"
