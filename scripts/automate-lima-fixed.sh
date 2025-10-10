#!/usr/bin/env bash
set -e

echo "=== Lima VM Automated Testing ==="

# Ubuntu (already has pool)
echo "=== Testing ubuntu-zfs ==="
limactl copy install.sh ubuntu-zfs:/tmp/
limactl copy config.sh ubuntu-zfs:/tmp/
limactl copy zfs-datadog-lib.sh ubuntu-zfs:/tmp/
limactl copy *-datadog.sh ubuntu-zfs:/tmp/
limactl copy .env.local ubuntu-zfs:/tmp/
limactl shell ubuntu-zfs sudo bash /tmp/install.sh
limactl shell ubuntu-zfs sudo zpool scrub testpool
sleep 5
limactl shell ubuntu-zfs sudo zpool status testpool | grep scrub
echo "✓ ubuntu-zfs complete"

# Debian (load ZFS modules)
echo "=== Testing debian-zfs ==="
limactl shell debian-zfs sudo modprobe zfs
limactl copy install.sh debian-zfs:/tmp/
limactl copy config.sh debian-zfs:/tmp/
limactl copy zfs-datadog-lib.sh debian-zfs:/tmp/
limactl copy *-datadog.sh debian-zfs:/tmp/
limactl copy .env.local debian-zfs:/tmp/
limactl shell debian-zfs sudo bash /tmp/install.sh
limactl shell debian-zfs 'sudo mkdir -p /tmp/zfs-test && sudo dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=256 && sudo dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=256 && sudo zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img'
limactl shell debian-zfs sudo zpool scrub testpool
sleep 5
limactl shell debian-zfs sudo zpool status testpool | grep scrub
echo "✓ debian-zfs complete"

echo "=== Lima Testing Complete ==="
echo "Ubuntu: ✓"
echo "Debian: ✓"
echo "Rocky: ✗ (ARM64 ZFS not available)"
