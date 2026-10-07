#!/usr/bin/env bash
set -e

echo "=== Lima VM Automated Testing ==="

# Keep the payload identical to the guarded installer; no public checksum/I/O
# helpers or all-event router may enter the ZED scan directory.
payload=(
  install.sh config.sh zfs-datadog-lib.sh
  statechange-datadog.sh scrub_start-datadog.sh scrub_finish-datadog.sh
  resilver_start-datadog.sh resilver_finish-datadog.sh
  config_sync-datadog.sh pool_import-datadog.sh pool_destroy-datadog.sh
  vdev_attach-datadog.sh vdev_remove-datadog.sh
  ereport.fs.zfs.checksum-datadog.sh ereport.fs.zfs.io-datadog.sh
  checksum-error.sh io-error.sh
)

# Copy all files to ubuntu-zfs
echo "=== Testing ubuntu-zfs ==="
limactl copy "${payload[@]}" ubuntu-zfs:/tmp/

# Install and test
limactl shell ubuntu-zfs sudo mkdir -p /root/zfs-datadog-src
limactl shell ubuntu-zfs sudo sh -c 'cp /tmp/*.sh /root/zfs-datadog-src/ && chmod go-w /root/zfs-datadog-src/*.sh && sh /root/zfs-datadog-src/install.sh'
limactl shell ubuntu-zfs sudo zpool scrub testpool
sleep 5
limactl shell ubuntu-zfs 'sudo zpool status testpool | grep scrub'
echo "✓ ubuntu-zfs: Zedlets deployed, scrub executed"

# Copy all files to debian-zfs
echo "=== Testing debian-zfs ==="
limactl shell debian-zfs sudo modprobe zfs
limactl copy "${payload[@]}" debian-zfs:/tmp/

# Install
limactl shell debian-zfs sudo mkdir -p /root/zfs-datadog-src
limactl shell debian-zfs sudo sh -c 'cp /tmp/*.sh /root/zfs-datadog-src/ && chmod go-w /root/zfs-datadog-src/*.sh && sh /root/zfs-datadog-src/install.sh'

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
