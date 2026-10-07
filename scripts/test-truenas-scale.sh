#!/bin/bash
#
# Automated TrueNAS SCALE Testing
# Deploys and tests POSIX-compatible zedlets
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_PORT=2222
SSH_HOST=localhost
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "========================================"
echo "TrueNAS SCALE Zedlet Testing"
echo "========================================"
echo ""

# Wait for SSH
log_info "Waiting for SSH to become available..."
if ! ./wait-for-ssh.sh "$SSH_HOST" "$SSH_PORT" 600; then
    log_error "SSH not available. Complete TrueNAS installation first."
    exit 1
fi

log_success "SSH connection established"
echo ""

# Copy zedlets
log_info "Copying zedlets to TrueNAS SCALE..."
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" 'mkdir -m 700 /root/zfs-datadog-src && mkdir -m 700 /root/zfs-datadog-test'
scp "${SSH_OPTS[@]}" -P "$SSH_PORT" \
    "$SCRIPT_DIR/zfs-datadog-lib.sh" \
    "$SCRIPT_DIR/config.sh" \
    "$SCRIPT_DIR/statechange-datadog.sh" \
    "$SCRIPT_DIR/scrub_finish-datadog.sh" \
    "$SCRIPT_DIR/resilver_finish-datadog.sh" \
    "$SCRIPT_DIR/install.sh" \
    "$SCRIPT_DIR/scrub_start-datadog.sh" \
    "$SCRIPT_DIR/resilver_start-datadog.sh" \
    "$SCRIPT_DIR/config_sync-datadog.sh" \
    "$SCRIPT_DIR/pool_import-datadog.sh" \
    "$SCRIPT_DIR/pool_destroy-datadog.sh" \
    "$SCRIPT_DIR/vdev_attach-datadog.sh" \
    "$SCRIPT_DIR/vdev_remove-datadog.sh" \
    "$SCRIPT_DIR/ereport.fs.zfs.checksum-datadog.sh" \
    "$SCRIPT_DIR/ereport.fs.zfs.io-datadog.sh" \
    "$SCRIPT_DIR/checksum-error.sh" \
    "$SCRIPT_DIR/io-error.sh" \
    "$SCRIPT_DIR/payload.sha256" \
    "root@${SSH_HOST}:/root/zfs-datadog-src/"
scp "${SSH_OPTS[@]}" -P "$SSH_PORT" "$SCRIPT_DIR/../mock-datadog-server.py" "root@${SSH_HOST}:/root/zfs-datadog-test/"

log_success "Files copied"
echo ""

# Install zedlets
log_info "Installing zedlets..."
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" bash <<'INSTALL'
set -e
cd /root/zfs-datadog-src
set -- $(openssl dgst -sha256 payload.sha256)
[ "$2" = 1de71ec228764649a5310e00ca76054a8488be3c9ccf92dff60cc2124c992e16 ]
set -- $(openssl dgst -sha256 install.sh)
[ "$2" = c0b4db0fc4bafb554e40f7e54f21b5bf664ef52717159c46302a44ec6a015835 ]
ZFS_DD_EXPECTED_MANIFEST_SHA=1de71ec228764649a5310e00ca76054a8488be3c9ccf92dff60cc2124c992e16 sh ./install.sh
systemctl stop zfs-zed
if systemctl is-active --quiet zfs-zed; then exit 1; fi
cat > /etc/zfs/zed.d/config.sh <<'CONFIG'
DD_API_KEY="test-key"
DD_API_URL="http://localhost:8080"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,system:truenas-scale"
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
CONFIG

systemctl start zfs-zed
systemctl is-active --quiet zfs-zed
sleep 2

echo "Zedlets installed"
INSTALL

log_success "Zedlets installed and ZED restarted"
echo ""

# Start mock Datadog server
log_info "Starting mock Datadog server..."
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" bash <<'START_MOCK'
set -- $(openssl dgst -sha256 /root/zfs-datadog-test/mock-datadog-server.py)
[ "$2" = 0b3de0cc401b5a64a54a86cfa09cffeb79b143e1b55f9e12bafc9c9ab8cb087b ] || exit 1
pkill -f mock-datadog-server.py 2>/dev/null || true
nohup python3 /root/zfs-datadog-test/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
sleep 3
START_MOCK

log_success "Mock server started"
echo ""

# Create test pool
log_info "Creating test pool..."
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" bash <<'CREATE_POOL'
set -e

# Create disk images
mkdir -p /tmp/zfs-test
dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=512 status=none
dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=512 status=none

# Create mirrored pool
zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img

echo "Test pool created:"
zpool status testpool
CREATE_POOL

log_success "Test pool created"
echo ""

# Trigger scrub
log_info "Triggering scrub event..."
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" bash <<'SCRUB'
zpool scrub testpool
while zpool status testpool | grep -q "scan: scrub in progress"; do
    sleep 1
done
sleep 3
echo "Scrub completed"
SCRUB

log_success "Scrub completed"
echo ""

# Check results
log_info "Checking captured events..."
EVENTS=$(ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" "curl -s http://localhost:8080/status" | jq '.events_received')

if [ "$EVENTS" -gt 0 ]; then
    log_success "Events captured: $EVENTS"
    ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" "root@${SSH_HOST}" "curl -s http://localhost:8080/status" | jq '.'
else
    log_error "No events captured"
    exit 1
fi

echo ""
echo "========================================"
echo "TrueNAS SCALE Test Complete"
echo "========================================"
echo ""
echo "✓ POSIX scripts work on TrueNAS SCALE"
echo "✓ Events captured successfully"
echo "✓ Datadog integration functional"
