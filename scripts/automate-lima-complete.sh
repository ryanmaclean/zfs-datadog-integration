#!/usr/bin/env bash
set -e

echo "=== Lima VM Automated Testing ==="

# Copy all files to ubuntu-zfs
echo "=== Testing ubuntu-zfs ==="
limactl copy install.sh config.sh zfs-datadog-lib.sh .env.local ubuntu-zfs:/tmp/
limactl copy all-datadog.sh scrub_finish-datadog.sh resilver_finish-datadog.sh statechange-datadog.sh checksum-error.sh io-error.sh ubuntu-zfs:/tmp/

# Install and test
limactl shell ubuntu-zfs sudo bash /tmp/install.sh
limactl shell ubuntu-zfs sudo zpool scrub testpool
sleep 5
limactl shell ubuntu-zfs 'sudo zpool status testpool | grep scrub'
echo "✓ ubuntu-zfs: Zedlets deployed, scrub executed"

# Copy all files to debian-zfs
echo "=== Testing debian-zfs ==="
limactl shell debian-zfs sudo modprobe zfs
limactl copy install.sh config.sh zfs-datadog-lib.sh .env.local debian-zfs:/tmp/
limactl copy all-datadog.sh scrub_finish-datadog.sh resilver_finish-datadog.sh statechange-datadog.sh checksum-error.sh io-error.sh debian-zfs:/tmp/

# Install
limactl shell debian-zfs sudo bash /tmp/install.sh

# Create pool
limactl shell debian-zfs 'sudo mkdir -p /tmp/zfs-test && sudo dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=256 2>/dev/null && sudo dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=256 2>/dev/null && sudo zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img'

# Scrub
limactl shell debian-zfs sudo zpool scrub testpool
sleep 5
limactl shell debian-zfs 'sudo zpool status testpool | grep scrub'
echo "✓ debian-zfs: Zedlets deployed, pool created, scrub executed"

echo ""
echo "=== Lima Testing Results ==="
echo "✓ Ubuntu 24.04: Complete"
echo "✓ Debian 12: Complete"
echo "✗ Rocky 9: ARM64 ZFS not available"
echo ""
echo "Check Datadog for events from ubuntu-zfs and debian-zfs"
