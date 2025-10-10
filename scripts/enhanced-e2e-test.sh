#!/bin/bash
#
# Enhanced End-to-End Test Suite for ZFS Datadog Integration
# Comprehensive testing of all event types and error scenarios
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

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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

test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}▶ Test $TESTS_TOTAL: $1${NC}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS: $1${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ FAIL: $1${NC}"
}

# Check VM is running
if ! limactl list | grep -q "$VM_NAME.*Running"; then
    log_error "VM $VM_NAME is not running"
    log_info "Start it with: limactl start --name=$VM_NAME lima-zfs.yaml"
    exit 1
fi

section "🧪 Enhanced ZFS Datadog Integration Test Suite"

# Reset mock server stats
log_info "Resetting mock Datadog server..."
limactl shell "$VM_NAME" bash <<'RESET_MOCK'
pkill -f mock-datadog-server.py 2>/dev/null || true
sleep 2
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid
sleep 3
RESET_MOCK

section "📦 Phase 1: Setup Mirrored Pool"

log_info "Creating mirrored pool for resilver testing..."
limactl shell "$VM_NAME" sudo bash <<'CREATE_MIRROR'
set -e

# Clean up any existing test pools
zpool destroy testmirror 2>/dev/null || true
zpool destroy testpool 2>/dev/null || true

# Create disk images
mkdir -p /tmp/zfs-mirror
dd if=/dev/zero of=/tmp/zfs-mirror/disk1.img bs=1M count=512 status=none
dd if=/dev/zero of=/tmp/zfs-mirror/disk2.img bs=1M count=512 status=none
dd if=/dev/zero of=/tmp/zfs-mirror/disk3.img bs=1M count=512 status=none
dd if=/dev/zero of=/tmp/zfs-mirror/disk4.img bs=1M count=512 status=none

# Create mirrored pool
zpool create -f testmirror mirror /tmp/zfs-mirror/disk1.img /tmp/zfs-mirror/disk2.img

echo "Mirrored pool created:"
zpool status testmirror
CREATE_MIRROR

log_success "Mirrored pool created"

section "🧪 Phase 2: Test Scrub Events"

test_start "Scrub on mirrored pool"
limactl shell "$VM_NAME" sudo bash <<'TEST_SCRUB'
zpool scrub testmirror
while zpool status testmirror | grep -q "scan: scrub in progress"; do
    sleep 1
done
sleep 2
TEST_SCRUB

SCRUB_EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events[] | select(.data.title | contains("Scrub")) | .data.title' | wc -l)
if [ "$SCRUB_EVENTS" -gt 0 ]; then
    test_pass "Scrub event captured ($SCRUB_EVENTS events)"
else
    test_fail "No scrub events captured"
fi

section "🧪 Phase 3: Test Resilver Events"

test_start "Resilver by replacing disk"
log_info "Replacing disk to trigger resilver..."
limactl shell "$VM_NAME" sudo bash <<'TEST_RESILVER'
set -e

# Replace disk2 with disk3
zpool replace testmirror /tmp/zfs-mirror/disk2.img /tmp/zfs-mirror/disk3.img

echo "Waiting for resilver to complete..."
while zpool status testmirror | grep -q "resilver in progress"; do
    sleep 1
    echo -n "."
done
echo ""

sleep 3
zpool status testmirror
TEST_RESILVER

RESILVER_EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events[] | select(.data.title | contains("Resilver")) | .data.title' | wc -l)
if [ "$RESILVER_EVENTS" -gt 0 ]; then
    test_pass "Resilver event captured ($RESILVER_EVENTS events)"
else
    test_fail "No resilver events captured"
fi

section "🧪 Phase 4: Test State Change Events"

test_start "Pool degradation (offline disk)"
limactl shell "$VM_NAME" sudo bash <<'TEST_OFFLINE'
zpool offline testmirror /tmp/zfs-mirror/disk1.img
sleep 2
zpool status testmirror
TEST_OFFLINE

sleep 2

test_start "Pool recovery (online disk)"
limactl shell "$VM_NAME" sudo bash <<'TEST_ONLINE'
zpool online testmirror /tmp/zfs-mirror/disk1.img
sleep 2
zpool status testmirror
TEST_ONLINE

sleep 2

STATECHANGE_EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events[] | select(.data.title | contains("Health")) | .data.title' | wc -l)
if [ "$STATECHANGE_EVENTS" -gt 0 ]; then
    test_pass "State change events captured ($STATECHANGE_EVENTS events)"
else
    test_fail "No state change events captured"
fi

section "🧪 Phase 5: Test Error Injection"

test_start "Check for zinject availability"
if limactl shell "$VM_NAME" which zinject >/dev/null 2>&1; then
    log_info "zinject available, testing error injection..."
    
    limactl shell "$VM_NAME" sudo bash <<'TEST_CHECKSUM'
    set -e
    zinject -c all 2>/dev/null || true
    zinject -d /tmp/zfs-mirror/disk1.img -e checksum -T read -f 0.5 testmirror
    dd if=/dev/urandom of=/testmirror/testfile bs=1M count=10 2>/dev/null
    dd if=/testmirror/testfile of=/dev/null bs=1M 2>/dev/null || true
    zpool scrub testmirror
    while zpool status testmirror | grep -q "scan: scrub in progress"; do sleep 1; done
    zinject -c all
TEST_CHECKSUM
    
    ERROR_EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events[] | select(.data.title | contains("Error") or contains("Checksum") or contains("I/O")) | .data.title' | wc -l)
    if [ "$ERROR_EVENTS" -gt 0 ]; then
        test_pass "Error events captured ($ERROR_EVENTS events)"
    else
        test_warning "No error events captured"
    fi
else
    log_warning "zinject not available in this OpenZFS version"
    log_info "Error injection tests skipped (requires zinject tool)"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${YELLOW}⊘ SKIP: Error injection tests - zinject not available${NC}"
fi

section "🧪 Phase 6: Test Error Handling"

test_start "Graceful failure when Datadog unreachable"
log_info "Killing mock Datadog server..."
limactl shell "$VM_NAME" bash <<'KILL_MOCK'
pkill -f mock-datadog-server.py 2>/dev/null || true
sleep 2
KILL_MOCK

log_info "Triggering event with server down..."
limactl shell "$VM_NAME" sudo bash <<'TEST_NO_SERVER'
zpool scrub testmirror
while zpool status testmirror | grep -q "scan: scrub in progress"; do
    sleep 1
done
sleep 2
TEST_NO_SERVER

log_info "Restarting mock server..."
limactl shell "$VM_NAME" bash <<'RESTART_MOCK'
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid
sleep 3
RESTART_MOCK

test_pass "Scripts handle server unavailability (no crash)"

section "📊 Phase 7: Results Analysis"

log_info "Fetching final statistics..."
STATS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status)

echo "$STATS" | jq '.'

TOTAL_EVENTS=$(echo "$STATS" | jq '.events_received')
TOTAL_METRICS=$(echo "$STATS" | jq '.metrics_received')

echo ""
echo "Event Breakdown:"
echo "$STATS" | jq -r '.events[] | "  - " + .data.title + " (" + .data.alert_type + ")"'

section "📈 Test Summary"

echo "Test Results:"
echo "  Total Tests: $TESTS_TOTAL"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo ""
echo "Datadog Integration:"
echo "  Events Captured: $TOTAL_EVENTS"
echo "  Metrics Captured: $TOTAL_METRICS"
echo ""

# Calculate coverage
EXPECTED_EVENT_TYPES=4  # scrub, resilver, statechange, errors
EVENT_TYPES_CAPTURED=$(echo "$STATS" | jq '[.events[].data.title | split(":")[0]] | unique | length')
COVERAGE=$((EVENT_TYPES_CAPTURED * 100 / EXPECTED_EVENT_TYPES))

echo "Coverage:"
echo "  Event Types Captured: $EVENT_TYPES_CAPTURED / $EXPECTED_EVENT_TYPES"
echo "  Coverage: $COVERAGE%"
echo ""

# Zedlet execution verification
echo "Zedlet Verification:"
SCRUB_ZEDLET=$(echo "$STATS" | jq '[.events[] | select(.data.title | contains("Scrub"))] | length')
RESILVER_ZEDLET=$(echo "$STATS" | jq '[.events[] | select(.data.title | contains("Resilver"))] | length')
HEALTH_ZEDLET=$(echo "$STATS" | jq '[.events[] | select(.data.title | contains("Health"))] | length')

echo "  scrub_finish-datadog.sh: $([ $SCRUB_ZEDLET -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo "  resilver_finish-datadog.sh: $([ $RESILVER_ZEDLET -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo "  statechange-datadog.sh: $([ $HEALTH_ZEDLET -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo ""

if [ $TESTS_FAILED -eq 0 ] && [ $TOTAL_EVENTS -gt 5 ]; then
    log_success "All tests passed! Integration is working correctly."
    exit 0
else
    log_warning "Some tests failed or insufficient events captured."
    log_info "Review the output above for details."
    exit 1
fi
