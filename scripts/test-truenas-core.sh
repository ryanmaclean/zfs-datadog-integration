#!/bin/sh
#
# Automated TrueNAS CORE Testing
# Deploys and tests POSIX-compatible zedlets on FreeBSD
#

set -e

SSH_PORT=2223
SSH_HOST=localhost
# Options shared by every ssh/scp call. POSIX sh has no arrays, so they are
# spelled out once here and each option stays its own argument.
tn_ssh() { ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" "$@"; }
tn_scp() { scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$SSH_PORT" "$@"; }

# Colors
GREEN=$(printf '\033[0;32m')
BLUE=$(printf '\033[0;34m')
RED=$(printf '\033[0;31m')
NC=$(printf '\033[0m')

log_info() { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }
log_success() { printf '%b\n' "${GREEN}[✓]${NC} $1"; }
log_error() { printf '%b\n' "${RED}[✗]${NC} $1"; }

echo "========================================"
echo "TrueNAS CORE Zedlet Testing"
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
log_info "Copying zedlets to TrueNAS CORE..."
tn_scp \
    zfs-datadog-lib.sh \
    config.sh \
    statechange-datadog.sh \
    scrub_finish-datadog.sh \
    resilver_finish-datadog.sh \
    all-datadog.sh \
    checksum-error.sh \
    io-error.sh \
    mock-datadog-server.py \
    root@${SSH_HOST}:/tmp/

log_success "Files copied"
echo ""

# Install zedlets
log_info "Installing zedlets (FreeBSD paths)..."
tn_ssh root@${SSH_HOST} bash <<'INSTALL'
set -e
cd /tmp

# Install to FreeBSD path
cp zfs-datadog-lib.sh /usr/local/etc/zfs/zed.d/
cp config.sh /usr/local/etc/zfs/zed.d/
cp statechange-datadog.sh /usr/local/etc/zfs/zed.d/
cp scrub_finish-datadog.sh /usr/local/etc/zfs/zed.d/
cp resilver_finish-datadog.sh /usr/local/etc/zfs/zed.d/
cp all-datadog.sh /usr/local/etc/zfs/zed.d/
cp checksum-error.sh /usr/local/etc/zfs/zed.d/
cp io-error.sh /usr/local/etc/zfs/zed.d/

chmod 755 /usr/local/etc/zfs/zed.d/*.sh
chmod 600 /usr/local/etc/zfs/zed.d/config.sh

# Configure
cat > /usr/local/etc/zfs/zed.d/config.sh <<'CONFIG'
DD_API_KEY="test-key"
DD_API_URL="http://localhost:8080"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,system:truenas-core"
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
CONFIG

# Restart ZED (FreeBSD service command)
service zfs-zed restart
sleep 2

echo "Zedlets installed"
INSTALL

log_success "Zedlets installed and ZED restarted"
echo ""

# Start mock Datadog server
log_info "Starting mock Datadog server..."
tn_ssh root@${SSH_HOST} bash <<'START_MOCK'
pkill -f mock-datadog-server.py 2>/dev/null || true
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
sleep 3
START_MOCK

log_success "Mock server started"
echo ""

# Create test pool
log_info "Creating test pool..."
tn_ssh root@${SSH_HOST} bash <<'CREATE_POOL'
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
tn_ssh root@${SSH_HOST} bash <<'SCRUB'
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
EVENTS=$(tn_ssh root@${SSH_HOST} "curl -s http://localhost:8080/status" | jq '.events_received')

if [ "$EVENTS" -gt 0 ]; then
    log_success "Events captured: $EVENTS"
    tn_ssh root@${SSH_HOST} "curl -s http://localhost:8080/status" | jq '.'
else
    log_error "No events captured"
    exit 1
fi

echo ""
echo "========================================"
echo "TrueNAS CORE Test Complete"
echo "========================================"
echo ""
echo "✓ POSIX scripts work on FreeBSD/TrueNAS CORE"
echo "✓ Events captured successfully"
echo "✓ Datadog integration functional"
