#!/usr/bin/env bash
# bash-required: BASH_SOURCE and Bash-specific arrays
set -e
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  checksum-error.sh io-error.sh payload.sha256
)

install_sealed_lima() {
  local vm=$1
  local file
  local guest_files=()
  local host_files=()
  limactl shell "$vm" mkdir -m 700 /tmp/zfs-datadog-upload
  for file in "${payload[@]}"; do
    host_files+=("$script_dir/$file")
  done
  limactl copy "${host_files[@]}" "$vm:/tmp/zfs-datadog-upload/"
  limactl shell "$vm" sudo mkdir -m 700 /root/zfs-datadog-src
  for file in "${payload[@]}"; do
    guest_files+=("/tmp/zfs-datadog-upload/$file")
  done
  limactl shell "$vm" sudo cp "${guest_files[@]}" /root/zfs-datadog-src/
  local verify_script
  verify_script=$(cat <<'VERIFY'
cd /root/zfs-datadog-src
set -- $(openssl dgst -sha256 payload.sha256)
[ "$2" = "77e67d33c1716d4760e5b8c67bdc91ef684937624e086498311d9dd4f72e7116" ] || exit 1
set -- $(openssl dgst -sha256 install.sh)
[ "$2" = "e3f8009df25e541b08fca0237f0f61e881bcb99e38723cc229b3df8a54fdbef3" ]
VERIFY
)
  limactl shell "$vm" sudo sh -ec "$verify_script"
  limactl shell "$vm" sudo env ZFS_DD_EXPECTED_MANIFEST_SHA=77e67d33c1716d4760e5b8c67bdc91ef684937624e086498311d9dd4f72e7116 sh /root/zfs-datadog-src/install.sh
}

if [ "${1:-}" = --sealed-install ]; then
  [ "$#" -eq 2 ] || { echo 'Usage: automate-lima-complete.sh --sealed-install VM' >&2; exit 2; }
  install_sealed_lima "$2"
  exit
fi

# Copy all files to ubuntu-zfs
echo "=== Testing ubuntu-zfs ==="
install_sealed_lima ubuntu-zfs

# Install and test
limactl shell ubuntu-zfs sudo zpool scrub testpool
sleep 5
limactl shell ubuntu-zfs 'sudo zpool status testpool | grep scrub'
echo "✓ ubuntu-zfs: Zedlets deployed, scrub executed"

# Copy all files to debian-zfs
echo "=== Testing debian-zfs ==="
limactl shell debian-zfs sudo modprobe zfs
install_sealed_lima debian-zfs

# Install

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
