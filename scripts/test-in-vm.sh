#!/bin/bash
#
# Test ZFS Datadog Integration in Lima VM
# This script runs inside the Lima VM to test the zedlets
#

set -e

VM_NAME="zfs-test"

echo "==================================="
echo "ZFS Datadog Integration Test Suite"
echo "==================================="
echo ""

# Check if VM is running
if ! limactl list | grep -q "$VM_NAME.*Running"; then
    echo "Starting Lima VM: $VM_NAME"
    limactl start --name="$VM_NAME" template://ubuntu-lts
    echo "Waiting for VM to be ready..."
    sleep 10
fi

echo "VM is running. Installing dependencies..."
echo ""

# Install ZFS and dependencies in VM
limactl shell "$VM_NAME" sudo bash <<'INSTALL_SCRIPT'
set -e

echo "Updating package lists..."
apt-get update -qq

echo "Installing ZFS utilities..."
apt-get install -y zfsutils-linux curl netcat-openbsd

echo "Loading ZFS kernel module..."
modprobe zfs || echo "ZFS module may already be loaded"

echo "Verifying ZFS installation..."
zfs --version

echo ""
echo "Creating test disk files for ZFS pool..."
mkdir -p /tmp/zfs-test
dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=512 2>/dev/null
dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=512 2>/dev/null

echo "Creating test ZFS pool..."
zpool create -f testpool /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img

echo "Verifying pool creation..."
zpool status testpool

echo ""
echo "ZFS setup complete!"
INSTALL_SCRIPT

echo ""
echo "Copying zedlets to VM..."

# Copy all necessary files to VM
limactl copy install.sh config.sh zfs-datadog-lib.sh \
    statechange-datadog.sh scrub_start-datadog.sh scrub_finish-datadog.sh \
    resilver_start-datadog.sh resilver_finish-datadog.sh \
    config_sync-datadog.sh pool_import-datadog.sh pool_destroy-datadog.sh \
    vdev_attach-datadog.sh vdev_remove-datadog.sh \
    ereport.fs.zfs.checksum-datadog.sh ereport.fs.zfs.io-datadog.sh \
    checksum-error.sh io-error.sh "$VM_NAME:/tmp/"

echo "Installing zedlets..."
limactl shell "$VM_NAME" sudo bash <<'INSTALL_ZEDLETS'
set -e

# Configure source for testing before the guarded activation.
cat > /tmp/config.sh <<'CONFIG'
#!/bin/bash
# Test configuration - logs to file instead of Datadog
DD_API_KEY="test-key-12345"
DD_SITE="datadoghq.com"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,service:zfs"
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
CONFIG

install -d -m 700 /root/zfs-datadog-src
cp /tmp/*.sh /root/zfs-datadog-src/
chmod go-w /root/zfs-datadog-src/*.sh
sh /root/zfs-datadog-src/install.sh
systemctl status zfs-zed --no-pager

echo ""
echo "Zedlets installed successfully!"
INSTALL_ZEDLETS

echo ""
echo "==================================="
echo "Running Tests"
echo "==================================="
echo ""

# Test 1: Scrub
echo "Test 1: Testing scrub monitoring..."
limactl shell "$VM_NAME" sudo bash <<'TEST_SCRUB'
set -e

echo "Starting scrub on testpool..."
zpool scrub testpool

echo "Waiting for scrub to complete..."
while zpool status testpool | grep -q "scan: scrub in progress"; do
    sleep 2
done

echo "Scrub completed!"
zpool status testpool

echo ""
echo "Checking ZED logs for scrub event..."
tail -20 /var/log/syslog | grep -i "scrub\|zed" || echo "Check /var/log/syslog for ZED output"
TEST_SCRUB

echo ""
echo "Test 1 completed!"
echo ""

# Test 2: Pool status
echo "Test 2: Checking pool health..."
limactl shell "$VM_NAME" sudo bash <<'TEST_HEALTH'
zpool status testpool
echo ""
echo "Pool health check completed!"
TEST_HEALTH

echo ""
echo "==================================="
echo "Test Summary"
echo "==================================="
echo ""
echo "✓ Lima VM created and running"
echo "✓ ZFS installed and pool created"
echo "✓ Zedlets installed in /etc/zfs/zed.d/"
echo "✓ Scrub test executed"
echo ""
echo "To interact with the VM:"
echo "  limactl shell $VM_NAME"
echo ""
echo "To check ZED logs:"
echo "  limactl shell $VM_NAME sudo tail -f /var/log/syslog"
echo ""
echo "To check zpool status:"
echo "  limactl shell $VM_NAME sudo zpool status"
echo ""
echo "To stop the VM:"
echo "  limactl stop $VM_NAME"
echo ""
echo "To delete the VM:"
echo "  limactl delete $VM_NAME"
echo ""
