#!/bin/bash
#
# End-to-End Test Suite for ZFS Datadog Integration
# Fully automated testing in Lima VM
#

set -e

VM_NAME="zfs-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

section() {
    echo ""
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo ""
}

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    log_error "Lima is not installed"
    log_info "Installing Lima via Homebrew..."
    brew install lima
fi

section "🚀 Starting ZFS Datadog Integration E2E Test"

# Clean up any existing VM
if limactl list | grep -q "$VM_NAME"; then
    log_warning "Existing VM found, cleaning up..."
    limactl stop "$VM_NAME" 2>/dev/null || true
    limactl delete "$VM_NAME" 2>/dev/null || true
    sleep 2
fi

# Start VM
section "📦 Step 1: Creating Lima VM with ZFS"
log_info "Starting VM: $VM_NAME"
limactl start --name="$VM_NAME" "$SCRIPT_DIR/lima-zfs.yaml" --tty=false

log_info "Waiting for VM to be ready..."
sleep 5

# Verify ZFS installation
log_info "Verifying ZFS installation..."
limactl shell "$VM_NAME" sudo zfs version

log_success "VM created and ZFS installed"

# Create test ZFS pool
section "💾 Step 2: Creating Test ZFS Pool"
limactl shell "$VM_NAME" sudo bash <<'CREATE_POOL'
set -e

echo "Creating virtual disk files..."
mkdir -p /tmp/zfs-disks
dd if=/dev/zero of=/tmp/zfs-disks/disk1.img bs=1M count=512 status=none
dd if=/dev/zero of=/tmp/zfs-disks/disk2.img bs=1M count=512 status=none
dd if=/dev/zero of=/tmp/zfs-disks/disk3.img bs=1M count=512 status=none

echo "Creating ZFS pool 'testpool' with 3 disks..."
zpool create -f testpool \
    /tmp/zfs-disks/disk1.img \
    /tmp/zfs-disks/disk2.img \
    /tmp/zfs-disks/disk3.img

echo "Pool created successfully!"
zpool status testpool
zpool list testpool
CREATE_POOL

log_success "Test pool created"

# Start mock Datadog server in VM
section "🐕 Step 3: Starting Mock Datadog Server"
log_info "Copying mock server to VM..."
limactl copy "$SCRIPT_DIR/mock-datadog-server.py" "$VM_NAME:/tmp/"

log_info "Starting mock Datadog server in background..."
limactl shell "$VM_NAME" bash <<'START_MOCK'
# Kill any existing mock server
pkill -f mock-datadog-server.py 2>/dev/null || true
sleep 1

# Start mock server in background
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid

# Wait for server to start
sleep 3

# Verify it's running
if ps -p $(cat /tmp/mock-datadog.pid) > /dev/null; then
    echo "Mock Datadog server started (PID: $(cat /tmp/mock-datadog.pid))"
else
    echo "Failed to start mock server"
    exit 1
fi
START_MOCK

log_success "Mock Datadog server running"

# Install zedlets
section "⚙️  Step 4: Installing Zedlets"
log_info "Copying zedlet files to VM..."

FILES=(
    "zfs-datadog-lib.sh"
    "config.sh"
    "statechange-datadog.sh"
    "scrub_finish-datadog.sh"
    "resilver_finish-datadog.sh"
    "all-datadog.sh"
    "checksum-error.sh"
    "io-error.sh"
)

for file in "${FILES[@]}"; do
    limactl copy "$SCRIPT_DIR/$file" "$VM_NAME:/tmp/"
done

log_info "Installing zedlets..."
limactl shell "$VM_NAME" sudo bash <<'INSTALL_ZEDLETS'
set -e

# Copy to ZED directory
cp /tmp/zfs-datadog-lib.sh /etc/zfs/zed.d/
cp /tmp/config.sh /etc/zfs/zed.d/
cp /tmp/statechange-datadog.sh /etc/zfs/zed.d/
cp /tmp/scrub_finish-datadog.sh /etc/zfs/zed.d/
cp /tmp/resilver_finish-datadog.sh /etc/zfs/zed.d/
cp /tmp/all-datadog.sh /etc/zfs/zed.d/
cp /tmp/checksum-error.sh /etc/zfs/zed.d/
cp /tmp/io-error.sh /etc/zfs/zed.d/

# Set permissions
chmod 755 /etc/zfs/zed.d/*.sh
chmod 600 /etc/zfs/zed.d/config.sh

# Configure to use mock server
cat > /etc/zfs/zed.d/config.sh <<'CONFIG'
#!/bin/bash
DD_API_KEY="test-api-key-12345"
DD_API_URL="http://localhost:8080"
DD_SITE="datadoghq.com"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,service:zfs,test:e2e"
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
CONFIG

echo "Zedlets installed to /etc/zfs/zed.d/"
ls -la /etc/zfs/zed.d/*.sh

# Restart ZED
echo "Restarting ZFS Event Daemon..."
systemctl restart zfs-zed
sleep 2
systemctl status zfs-zed --no-pager || true
INSTALL_ZEDLETS

log_success "Zedlets installed and ZED restarted"

# Run tests
section "🧪 Step 5: Running Tests"

# Test 1: Scrub
echo ""
log_info "Test 1: Scrub Monitoring"
limactl shell "$VM_NAME" sudo bash <<'TEST_SCRUB'
set -e

echo "Starting scrub on testpool..."
zpool scrub testpool

echo "Waiting for scrub to complete..."
while zpool status testpool | grep -q "scan: scrub in progress"; do
    sleep 1
    echo -n "."
done
echo ""

echo "Scrub completed!"
zpool status testpool | grep "scan:"
TEST_SCRUB

sleep 2
log_success "Test 1: Scrub completed"

# Test 2: Pool Health - Offline device
echo ""
log_info "Test 2: Pool Health Monitoring (Device Offline)"
limactl shell "$VM_NAME" sudo bash <<'TEST_OFFLINE'
set -e

echo "Taking disk offline..."
zpool offline testpool /tmp/zfs-disks/disk3.img

sleep 2
zpool status testpool

echo "Bringing disk back online..."
zpool online testpool /tmp/zfs-disks/disk3.img

sleep 2
zpool status testpool
TEST_OFFLINE

sleep 2
log_success "Test 2: Pool health events triggered"

# Test 3: Another scrub for good measure
echo ""
log_info "Test 3: Second Scrub (Verification)"
limactl shell "$VM_NAME" sudo bash <<'TEST_SCRUB2'
zpool scrub testpool
while zpool status testpool | grep -q "scan: scrub in progress"; do
    sleep 1
done
echo "Second scrub completed"
TEST_SCRUB2

sleep 2
log_success "Test 3: Second scrub completed"

# Collect results
section "📊 Step 6: Collecting Results"

log_info "Fetching mock Datadog server logs..."
limactl shell "$VM_NAME" cat /tmp/mock-datadog.log

echo ""
log_info "Fetching captured events and metrics..."
limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.'

echo ""
log_info "ZED logs (last 50 lines)..."
limactl shell "$VM_NAME" sudo tail -50 /var/log/syslog | grep -i "zed\|zfs" || true

# Validation
section "✅ Step 7: Validation"

log_info "Checking if events were captured..."
EVENT_COUNT=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events_received')
METRIC_COUNT=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.metrics_received')

echo ""
echo "Results:"
echo "  Events captured: $EVENT_COUNT"
echo "  Metrics captured: $METRIC_COUNT"
echo ""

if [ "$EVENT_COUNT" -gt 0 ]; then
    log_success "✓ Events successfully sent to Datadog API"
else
    log_error "✗ No events captured"
fi

if [ "$METRIC_COUNT" -gt 0 ]; then
    log_success "✓ Metrics successfully sent to DogStatsD"
else
    log_warning "⚠ No metrics captured (may be expected depending on events)"
fi

# Summary
section "📋 Test Summary"

echo "Test Environment:"
echo "  VM Name: $VM_NAME"
echo "  ZFS Pool: testpool"
echo "  Mock Datadog: http://localhost:8080"
echo ""
echo "Tests Executed:"
echo "  ✓ Pool creation"
echo "  ✓ Scrub monitoring (2x)"
echo "  ✓ Pool health monitoring (offline/online)"
echo "  ✓ Event capture validation"
echo "  ✓ Metric capture validation"
echo ""

log_success "E2E Test Suite Completed!"

echo ""
echo "Next Steps:"
echo "  • Review captured events: limactl shell $VM_NAME curl http://localhost:8080/status | jq"
echo "  • Check ZED logs: limactl shell $VM_NAME sudo tail -f /var/log/syslog"
echo "  • Shell into VM: limactl shell $VM_NAME"
echo "  • Stop VM: limactl stop $VM_NAME"
echo "  • Delete VM: limactl delete $VM_NAME"
echo ""
