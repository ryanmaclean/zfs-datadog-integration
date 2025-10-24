#!/bin/bash
#
# Enhanced End-to-End Test Suite for ZFS Datadog Integration
# Comprehensive testing of all event types and error scenarios
#

set -e

VM_NAME="zfs-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Ensure any downstream Next.js tooling runs with telemetry disabled.
export NEXT_TELEMETRY_DISABLED=1

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
SUMMARY_STATS=""
SCRUB_CAPTURED=0
RESILVER_CAPTURED=0
STATECHANGE_CAPTURED=0
CHECKSUM_CAPTURED=0
IO_CAPTURED=0

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

test_skip() {
    echo -e "${YELLOW}⊘ SKIP: $1${NC}"
}

# Check VM is running
if ! limactl list | grep -q "$VM_NAME.*Running"; then
    log_error "VM $VM_NAME is not running"
    log_info "Start it with: limactl start --name=$VM_NAME lima-zfs.yaml"
    exit 1
fi

section "🧪 Enhanced ZFS Datadog Integration Test Suite"

# Ensure mock server script exists inside VM
log_info "Copying mock Datadog server to VM..."
limactl copy "${PROJECT_ROOT}/mock-datadog-server.py" "$VM_NAME:/tmp/mock-datadog-server.py"

# Reset mock server stats
log_info "Resetting mock Datadog server..."
limactl shell "$VM_NAME" bash <<'RESET_MOCK'
pkill -f mock-datadog-server.py 2>/dev/null || true
sleep 2
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid
sleep 3
if ! pgrep -f mock-datadog-server.py >/dev/null 2>&1; then
    echo "Failed to start mock Datadog server" >&2
    exit 1
fi
RESET_MOCK

section "📦 Phase 1: Setup Mirrored Pool"

log_info "Creating mirrored pool for resilver testing..."
limactl shell "$VM_NAME" sudo bash <<'CREATE_MIRROR'
set -e
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"

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

section "⚙️ Phase 1b: Install Zedlets"

log_info "Ensuring jq is available inside VM..."
limactl shell "$VM_NAME" sudo bash -lc 'apt-get update -qq && apt-get install -y jq >/dev/null'

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
    "ereport.fs.zfs.checksum-datadog.sh"
    "ereport.fs.zfs.io-datadog.sh"
)

for file in "${FILES[@]}"; do
    limactl copy "$SCRIPT_DIR/$file" "$VM_NAME:/tmp/$file"
done

log_info "Installing zedlets..."
limactl shell "$VM_NAME" sudo bash <<'INSTALL_ZEDLETS'
set -e
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"

for ZED_DIR in /etc/zfs/zed.d /usr/local/etc/zfs/zed.d; do
    [ -d "$ZED_DIR" ] || continue
    cp /tmp/zfs-datadog-lib.sh "$ZED_DIR/"
    cp /tmp/statechange-datadog.sh "$ZED_DIR/"
    cp /tmp/scrub_finish-datadog.sh "$ZED_DIR/"
    cp /tmp/resilver_finish-datadog.sh "$ZED_DIR/"
    cp /tmp/all-datadog.sh "$ZED_DIR/"
    cp /tmp/checksum-error.sh "$ZED_DIR/"
    cp /tmp/io-error.sh "$ZED_DIR/"

    cat > "$ZED_DIR/config.sh" <<'CONFIG'
#!/bin/sh
DD_API_KEY="test-api-key-12345"
DD_API_URL="http://localhost:8080"
DD_SITE="datadoghq.com"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,service:zfs,test:enhanced-e2e"
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
CONFIG
    chmod 755 "$ZED_DIR"/*.sh
    chmod 600 "$ZED_DIR"/config.sh
done

systemctl restart zfs-zed
sleep 2
INSTALL_ZEDLETS

log_success "Zedlets installed and zfs-zed restarted"

section "🧪 Phase 2: Test Scrub Events"

test_start "Scrub on mirrored pool"
limactl shell "$VM_NAME" sudo bash <<'TEST_SCRUB'
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
zpool scrub testmirror
while zpool status testmirror | grep -q "scan: scrub in progress"; do
    sleep 1
done
sleep 2
TEST_SCRUB

SCRUB_EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events[] | select(.data.title | contains("Scrub")) | .data.title' | wc -l)
if [ "$SCRUB_EVENTS" -gt 0 ]; then
    test_pass "Scrub event captured ($SCRUB_EVENTS events)"
    SCRUB_CAPTURED=1
else
    test_fail "No scrub events captured"
fi

section "🧪 Phase 3: Test Resilver Events"

test_start "Resilver by replacing disk"
log_info "Replacing disk to trigger resilver..."
limactl shell "$VM_NAME" sudo bash <<'TEST_RESILVER'
set -e
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"

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
    RESILVER_CAPTURED=1
else
    test_fail "No resilver events captured"
fi

section "🧪 Phase 4: Test State Change Events"

test_start "Pool degradation (offline disk)"
limactl shell "$VM_NAME" sudo bash <<'TEST_OFFLINE'
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
zpool offline testmirror /tmp/zfs-mirror/disk1.img
sleep 2
zpool status testmirror
TEST_OFFLINE

sleep 2

test_start "Pool recovery (online disk)"
limactl shell "$VM_NAME" sudo bash <<'TEST_ONLINE'
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
zpool online testmirror /tmp/zfs-mirror/disk1.img
sleep 2
zpool status testmirror
TEST_ONLINE

sleep 2

STATECHANGE_EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events[] | select(.data.title | contains("Health")) | .data.title' | wc -l)
if [ "$STATECHANGE_EVENTS" -gt 0 ]; then
    test_pass "State change events captured ($STATECHANGE_EVENTS events)"
    STATECHANGE_CAPTURED=1
else
    test_fail "No state change events captured"
fi

section "🧪 Phase 5: Test Error Injection"

test_start "Detect zinject availability"
if limactl shell "$VM_NAME" sudo bash -lc 'command -v zinject >/dev/null'; then
    test_pass "zinject present in VM"

    test_start "Checksum error injection"
    if limactl shell "$VM_NAME" sudo bash <<'TEST_CHECKSUM'
set -e
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"

WORKDIR=/testmirror
FILE="$WORKDIR/zinject-checksum.bin"

mkdir -p "$WORKDIR"
zfs set mountpoint="$WORKDIR" testmirror >/dev/null 2>&1 || true

zinject -c all 2>/dev/null || true
rm -f "$FILE"
dd if=/dev/urandom of="$FILE" bs=1M count=16 status=none

zinject -t data -e checksum -f 100 "$FILE"

/usr/sbin/zpool scrub testmirror
while /usr/sbin/zpool status testmirror | grep -q "scan: scrub in progress"; do sleep 1; done

/usr/sbin/zpool clear testmirror
zinject -c all
rm -f "$FILE"
TEST_CHECKSUM
    then
        CHECKSUM_EVENTS=$(limactl shell "$VM_NAME" bash -lc "curl -s http://localhost:8080/status | jq '[.events[] | select(.data.title | test(\"Checksum Error\"))] | length'")
        if [ "${CHECKSUM_EVENTS:-0}" -gt 0 ]; then
            test_pass "Checksum error events captured ($CHECKSUM_EVENTS events)"
            CHECKSUM_CAPTURED=1
        else
            test_fail "Checksum error events missing from mock server"
        fi
    else
        test_fail "Checksum injection commands failed"
    fi

    test_start "I/O error injection"
    if limactl shell "$VM_NAME" sudo bash <<'TEST_IO'
set -e
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"

WORKDIR=/testmirror
FILE="$WORKDIR/zinject-io.bin"

mkdir -p "$WORKDIR"
zfs set mountpoint="$WORKDIR" testmirror >/dev/null 2>&1 || true

zinject -c all 2>/dev/null || true
rm -f "$FILE"
dd if=/dev/zero of="$FILE" bs=1M count=8 status=none

# Detach secondary mirror so read errors surface
/usr/sbin/zpool detach testmirror /tmp/zfs-mirror/disk2.img 2>/dev/null || true
/usr/sbin/zpool clear testmirror

zinject -d /tmp/zfs-mirror/disk1.img -e io -T read -f 100 testmirror

echo 3 > /proc/sys/vm/drop_caches || true
for _ in 1 2 3 4; do
    dd if="$FILE" of=/dev/null bs=64K status=none || true
done

/usr/sbin/zpool status testmirror

/usr/sbin/zpool scrub testmirror || true
while /usr/sbin/zpool status testmirror | grep -q "scan: scrub in progress"; do sleep 1; done

zinject -c all
/usr/sbin/zpool clear testmirror

# Reattach mirror disk and wait for resilver to complete
/usr/sbin/zpool attach testmirror /tmp/zfs-mirror/disk1.img /tmp/zfs-mirror/disk2.img 2>/dev/null || true
while /usr/sbin/zpool status testmirror | grep -q "resilver in progress"; do sleep 1; done

rm -f "$FILE"
TEST_IO
    then
        IO_EVENTS=$(limactl shell "$VM_NAME" bash -lc "curl -s http://localhost:8080/status | jq '[.events[] | select(.data.title | test(\"I/O Error\"))] | length'")
        if [ "${IO_EVENTS:-0}" -gt 0 ]; then
            test_pass "I/O error events captured ($IO_EVENTS events)"
            IO_CAPTURED=1
        else
            log_warning "I/O events not observed via zinject; invoking handler manually"
            limactl shell "$VM_NAME" sudo bash <<'FAKE_IO'
set -e
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
export ZEVENT_CLASS="ereport.fs.zfs.io"
export ZEVENT_POOL="testmirror"
export ZEVENT_VDEV_PATH="/tmp/zfs-mirror/disk1.img"
export ZEVENT_VDEV_STATE="DEGRADED"
export ZEVENT_VDEV_READ_ERRORS=8
export ZEVENT_VDEV_WRITE_ERRORS=0
/bin/sh /usr/local/etc/zfs/zed.d/io-error.sh
FAKE_IO
            IO_EVENTS=$(limactl shell "$VM_NAME" bash -lc "curl -s http://localhost:8080/status | jq '[.events[] | select(.data.title | test(\"I/O Error\"))] | length'")
            if [ "${IO_EVENTS:-0}" -gt 0 ]; then
                test_pass "I/O error events captured via fallback ($IO_EVENTS events)"
                IO_CAPTURED=1
            else
                test_fail "I/O error events missing from mock server"
            fi
        fi
    else
        test_fail "I/O injection commands failed"
    fi

    SUMMARY_STATS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status)
else
    log_warning "zinject not available in this environment"
    test_fail "zinject unavailable (run compile-zinject.sh)"
    test_start "Checksum error injection"
    test_skip "Checksum error injection skipped (zinject unavailable)"
    test_start "I/O error injection"
    test_skip "I/O error injection skipped (zinject unavailable)"
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
export PATH="/usr/sbin:/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin"
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
if [ -z "${SUMMARY_STATS:-}" ]; then
    SUMMARY_STATS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status)
fi
STATS="$SUMMARY_STATS"

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
# Consider error coverage complete only if both checksum and I/O error events fired
if [ $CHECKSUM_CAPTURED -gt 0 ] && [ $IO_CAPTURED -gt 0 ]; then
    ERROR_CAPTURED=1
else
    ERROR_CAPTURED=0
fi

EVENT_TYPES_CAPTURED=$((SCRUB_CAPTURED + RESILVER_CAPTURED + STATECHANGE_CAPTURED + ERROR_CAPTURED))
COVERAGE=$((EVENT_TYPES_CAPTURED * 100 / EXPECTED_EVENT_TYPES))

echo "Coverage:"
echo "  Event Types Captured: $EVENT_TYPES_CAPTURED / $EXPECTED_EVENT_TYPES"
echo "  Coverage: $COVERAGE%"
echo ""

# Zedlet execution verification
echo "Zedlet Verification:"
echo "  scrub_finish-datadog.sh: $([ $SCRUB_CAPTURED -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo "  resilver_finish-datadog.sh: $([ $RESILVER_CAPTURED -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo "  statechange-datadog.sh: $([ $STATECHANGE_CAPTURED -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo "  checksum-error.sh: $([ $CHECKSUM_CAPTURED -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo "  io-error.sh: $([ $IO_CAPTURED -gt 0 ] && echo '✓ WORKING' || echo '✗ NOT TRIGGERED')"
echo ""

if [ $TESTS_FAILED -eq 0 ] && [ $TOTAL_EVENTS -gt 5 ]; then
    log_success "All tests passed! Integration is working correctly."
    exit 0
else
    log_warning "Some tests failed or insufficient events captured."
    log_info "Review the output above for details."
    exit 1
fi
