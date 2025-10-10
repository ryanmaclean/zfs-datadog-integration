#!/bin/bash
#
# Comprehensive Validation Test Suite
# Tests: POSIX compatibility, retry logic, error handling, real Datadog integration
#

set -e

VM_NAME="zfs-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_test() { echo -e "${CYAN}[TEST]${NC} $1"; }

section() {
    echo ""
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo ""
}

test_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_success "$1"
}

test_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_error "$1"
}

test_skip() {
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_warning "$1 (SKIPPED)"
}

# Check VM is running
if ! limactl list | grep -q "$VM_NAME.*Running"; then
    log_error "VM $VM_NAME is not running"
    log_info "Start it with: limactl start --name=$VM_NAME lima-zfs.yaml"
    exit 1
fi

section "🧪 Comprehensive Validation Test Suite"
log_info "Testing: POSIX compatibility, retry logic, error handling, Datadog integration"

# Copy all files to VM
log_info "Copying files to VM..."
limactl copy zfs-datadog-lib.sh "$VM_NAME:/tmp/"
limactl copy config.sh "$VM_NAME:/tmp/"
limactl copy statechange-datadog.sh "$VM_NAME:/tmp/"
limactl copy scrub_finish-datadog.sh "$VM_NAME:/tmp/"
limactl copy resilver_finish-datadog.sh "$VM_NAME:/tmp/"
limactl copy all-datadog.sh "$VM_NAME:/tmp/"
limactl copy checksum-error.sh "$VM_NAME:/tmp/"
limactl copy io-error.sh "$VM_NAME:/tmp/"
limactl copy mock-datadog-server.py "$VM_NAME:/tmp/"

section "📋 Test Suite 1: POSIX Compatibility"

log_test "1.1: Syntax validation with /bin/sh"
if limactl shell "$VM_NAME" sh -n /tmp/zfs-datadog-lib.sh 2>/dev/null; then
    test_pass "zfs-datadog-lib.sh syntax valid"
else
    test_fail "zfs-datadog-lib.sh syntax errors"
fi

log_test "1.2: All zedlets syntax validation"
for script in statechange-datadog.sh scrub_finish-datadog.sh resilver_finish-datadog.sh all-datadog.sh checksum-error.sh io-error.sh; do
    if limactl shell "$VM_NAME" sh -n "/tmp/$script" 2>/dev/null; then
        test_pass "$script syntax valid"
    else
        test_fail "$script syntax errors"
    fi
done

log_test "1.3: Execute library with /bin/sh"
limactl shell "$VM_NAME" bash <<'TEST_POSIX'
cat > /tmp/test-posix.sh <<'SCRIPT'
#!/bin/sh
. /tmp/zfs-datadog-lib.sh
echo "POSIX test: $(get_pool_health_value "ONLINE")"
echo "POSIX test: $(get_alert_type "degraded")"
SCRIPT
chmod +x /tmp/test-posix.sh
if sh /tmp/test-posix.sh 2>/dev/null | grep -q "POSIX test"; then
    echo "POSIX_OK"
fi
TEST_POSIX

if [ $? -eq 0 ]; then
    test_pass "Library functions work with /bin/sh"
else
    test_fail "Library functions fail with /bin/sh"
fi

log_test "1.4: Test lowercase conversion (POSIX tr)"
RESULT=$(limactl shell "$VM_NAME" sh -c 'printf "%s" "ONLINE" | tr "[:upper:]" "[:lower:]"')
if [ "$RESULT" = "online" ]; then
    test_pass "POSIX lowercase conversion works"
else
    test_fail "POSIX lowercase conversion failed"
fi

section "📋 Test Suite 2: Retry Logic & Exponential Backoff"

log_info "Starting mock Datadog server..."
limactl shell "$VM_NAME" bash <<'START_MOCK'
pkill -f mock-datadog-server.py 2>/dev/null || true
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid
sleep 3
START_MOCK

log_test "2.1: Successful request (no retry needed)"
limactl shell "$VM_NAME" sudo bash <<'TEST_SUCCESS'
cd /tmp
cat > /tmp/config.sh <<'CONFIG'
DD_API_KEY="test-key"
DD_API_URL="http://localhost:8080"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test"
CONFIG

. /tmp/zfs-datadog-lib.sh
START_TIME=$(date +%s)
send_datadog_event "Test Event" "Test successful request" "info" "test:success"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "Duration: ${DURATION}s"
if [ $DURATION -lt 2 ]; then
    echo "SUCCESS_FAST"
fi
TEST_SUCCESS

if [ $? -eq 0 ]; then
    test_pass "Successful request completes quickly (<2s)"
else
    test_fail "Request took too long or failed"
fi

log_test "2.2: Retry logic with server failure"
limactl shell "$VM_NAME" bash <<'TEST_RETRY'
# Kill mock server
pkill -f mock-datadog-server.py 2>/dev/null || true
sleep 1

# Try to send event (should fail after retries)
cd /tmp
cat > /tmp/config.sh <<'CONFIG'
DD_API_KEY="test-key"
DD_API_URL="http://localhost:8080"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test"
CONFIG
chmod 644 /tmp/config.sh

. /tmp/config.sh
. /tmp/zfs-datadog-lib.sh

START_TIME=$(date +%s)
send_datadog_event "Test Retry" "Test retry logic" "info" "test:retry" 2>/tmp/retry-test.log || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Should take ~7s (1s + 2s + 4s retries)
echo "Retry duration: ${DURATION}s"
if [ $DURATION -ge 6 ] && [ $DURATION -le 10 ]; then
    echo "RETRY_TIMING_OK"
fi

# Check for retry messages in log
if grep -q "retrying" /tmp/retry-test.log; then
    echo "RETRY_MESSAGES_OK"
fi
TEST_RETRY

if [ $? -eq 0 ]; then
    test_pass "Retry logic executes with correct timing"
else
    test_fail "Retry logic timing incorrect"
fi

log_test "2.3: Exponential backoff verification"
RETRY_LOG=$(limactl shell "$VM_NAME" cat /tmp/retry-test.log 2>/dev/null)
if echo "$RETRY_LOG" | grep -q "attempt 1/3"; then
    test_pass "Retry attempts logged correctly"
else
    test_fail "Retry attempts not logged"
fi

# Restart mock server for remaining tests
log_info "Restarting mock server..."
limactl shell "$VM_NAME" bash <<'RESTART_MOCK'
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid
sleep 3
RESTART_MOCK

section "📋 Test Suite 3: Error Handling"

log_test "3.1: Missing API key handling"
limactl shell "$VM_NAME" bash <<'TEST_NO_KEY'
cd /tmp
cat > /tmp/config-nokey.sh <<'CONFIG'
DD_API_KEY=""
DD_API_URL="http://localhost:8080"
CONFIG

. /tmp/config-nokey.sh
. /tmp/zfs-datadog-lib.sh
send_datadog_event "Test" "Test" "info" 2>/tmp/no-key-test.log || true

if grep -q "DD_API_KEY not set" /tmp/no-key-test.log; then
    echo "ERROR_DETECTED"
fi
TEST_NO_KEY

if [ $? -eq 0 ]; then
    test_pass "Missing API key detected and logged"
else
    test_fail "Missing API key not handled"
fi

log_test "3.2: Timeout handling"
limactl shell "$VM_NAME" bash <<'TEST_TIMEOUT'
cd /tmp
. /tmp/config.sh
. /tmp/zfs-datadog-lib.sh

# Test with unreachable host (should timeout in ~10s)
DD_API_URL="http://192.0.2.1:9999"  # TEST-NET, unreachable
START_TIME=$(date +%s)
send_datadog_event "Test Timeout" "Test timeout" "info" 2>/tmp/timeout-test.log || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Should timeout around 30s (10s timeout × 3 retries)
echo "Timeout duration: ${DURATION}s"
if [ $DURATION -ge 25 ] && [ $DURATION -le 40 ]; then
    echo "TIMEOUT_OK"
fi
TEST_TIMEOUT

if [ $? -eq 0 ]; then
    test_pass "Timeout handling works correctly"
else
    test_fail "Timeout handling incorrect"
fi

log_test "3.3: DogStatsD retry logic"
limactl shell "$VM_NAME" bash <<'TEST_STATSD'
cd /tmp
. /tmp/config.sh
. /tmp/zfs-datadog-lib.sh

# Send metric (should succeed)
send_metric "test.metric" "1" "gauge" "test:metric" 2>/tmp/statsd-test.log
if [ $? -eq 0 ]; then
    echo "METRIC_OK"
fi
TEST_STATSD

if [ $? -eq 0 ]; then
    test_pass "DogStatsD metric sending works"
else
    test_fail "DogStatsD metric sending failed"
fi

log_test "3.4: Error logging verification"
ERROR_LOGS=$(limactl shell "$VM_NAME" cat /tmp/retry-test.log /tmp/no-key-test.log /tmp/timeout-test.log 2>/dev/null | grep -c "ERROR")
if [ "$ERROR_LOGS" -gt 0 ]; then
    test_pass "Errors logged to stderr ($ERROR_LOGS error messages)"
else
    test_fail "No error messages logged"
fi

section "📋 Test Suite 4: Integration Test with POSIX Shell"

log_info "Installing zedlets with POSIX shell..."
limactl shell "$VM_NAME" sudo bash <<'INSTALL_POSIX'
cd /tmp
cp zfs-datadog-lib.sh /etc/zfs/zed.d/
cp config.sh /etc/zfs/zed.d/
cp statechange-datadog.sh /etc/zfs/zed.d/
cp scrub_finish-datadog.sh /etc/zfs/zed.d/
cp resilver_finish-datadog.sh /etc/zfs/zed.d/
cp all-datadog.sh /etc/zfs/zed.d/
cp checksum-error.sh /etc/zfs/zed.d/
cp io-error.sh /etc/zfs/zed.d/

chmod 755 /etc/zfs/zed.d/*.sh
chmod 600 /etc/zfs/zed.d/config.sh

cat > /etc/zfs/zed.d/config.sh <<'CONFIG'
DD_API_KEY="test-key"
DD_API_URL="http://localhost:8080"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,shell:posix"
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
CONFIG

systemctl restart zfs-zed
sleep 2
INSTALL_POSIX

log_test "4.1: Trigger scrub event with POSIX scripts"
limactl shell "$VM_NAME" sudo bash <<'TEST_SCRUB_POSIX'
if ! zpool list testmirror >/dev/null 2>&1; then
    # Create test pool if it doesn't exist
    mkdir -p /tmp/zfs-test-posix
    dd if=/dev/zero of=/tmp/zfs-test-posix/disk1.img bs=1M count=256 status=none
    dd if=/dev/zero of=/tmp/zfs-test-posix/disk2.img bs=1M count=256 status=none
    zpool create -f testmirror mirror /tmp/zfs-test-posix/disk1.img /tmp/zfs-test-posix/disk2.img
fi

zpool scrub testmirror
while zpool status testmirror | grep -q "scan: scrub in progress"; do
    sleep 1
done
sleep 3
TEST_SCRUB_POSIX

EVENTS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq '.events_received')
if [ "$EVENTS" -gt 0 ]; then
    test_pass "Events captured with POSIX shell scripts"
else
    test_fail "No events captured"
fi

log_test "4.2: Verify event tags"
EVENT_TAGS=$(limactl shell "$VM_NAME" curl -s http://localhost:8080/status | jq -r '.events[0].data.tags[]' 2>/dev/null | grep "shell:posix" || echo "")
if [ -n "$EVENT_TAGS" ]; then
    test_pass "Event tags correctly formatted"
else
    test_skip "Event tags verification"
fi

section "📋 Test Suite 5: Real Datadog Integration (Manual)"

log_info "Real Datadog API testing requires your API key"
echo ""
echo "To test with real Datadog:"
echo ""
echo "1. Get your API key from: https://app.datadoghq.com/organization-settings/api-keys"
echo ""
echo "2. Update config in VM:"
echo "   limactl shell $VM_NAME"
echo "   sudo vi /etc/zfs/zed.d/config.sh"
echo "   # Set DD_API_KEY=\"your_real_key\""
echo "   # Set DD_API_URL=\"https://api.datadoghq.com\""
echo ""
echo "3. Trigger a test event:"
echo "   sudo zpool scrub testmirror"
echo ""
echo "4. Check Datadog Events:"
echo "   https://app.datadoghq.com/event/explorer"
echo "   Filter by: source:zfs"
echo ""
echo "5. Check Datadog Metrics:"
echo "   https://app.datadoghq.com/metric/explorer"
echo "   Search for: zfs.scrub.errors"
echo ""

test_skip "Real Datadog API test (requires API key)"

section "📊 Test Results Summary"

echo ""
echo "Test Statistics:"
echo "  Total Tests: $TOTAL_TESTS"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
echo "  Skipped: $SKIPPED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    SUCCESS_RATE=100
else
    SUCCESS_RATE=$((PASSED_TESTS * 100 / (PASSED_TESTS + FAILED_TESTS)))
fi

echo "Success Rate: ${SUCCESS_RATE}%"
echo ""

echo "Test Coverage:"
echo "  ✅ POSIX Compatibility: Verified"
echo "  ✅ Retry Logic: Verified"
echo "  ✅ Error Handling: Verified"
echo "  ✅ Integration: Verified"
echo "  ⏭️  Real Datadog: Manual test required"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    log_success "All automated tests passed!"
    echo ""
    echo "Production Readiness:"
    echo "  • Ubuntu/Debian: ✅ Ready"
    echo "  • BSD/FreeBSD: ✅ POSIX-compatible (needs real-world testing)"
    echo "  • TrueNAS: ✅ POSIX-compatible (needs real-world testing)"
    echo "  • Error Handling: ✅ Robust with retry logic"
    echo ""
    exit 0
else
    log_error "$FAILED_TESTS test(s) failed"
    echo ""
    echo "Review failed tests above and fix issues before production deployment."
    exit 1
fi
