#!/bin/bash
#
# Test ZFS Datadog Integration on Multiple Distributions
# Tests: Ubuntu, Debian, Rocky, Fedora, Arch
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

section() {
    echo ""
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    echo ""
}

# Test results
declare -A RESULTS

test_distro() {
    local distro=$1
    local vm_name="${distro}-zfs"
    local config_file="lima-${distro}.yaml"
    
    section "Testing $distro"
    
    # Check if config exists
    if [ ! -f "$config_file" ]; then
        log_error "Config file $config_file not found"
        RESULTS[$distro]="SKIP"
        return 1
    fi
    
    # Clean up existing VM
    if limactl list | grep -q "$vm_name"; then
        log_info "Cleaning up existing $vm_name VM..."
        limactl stop "$vm_name" 2>/dev/null || true
        limactl delete "$vm_name" 2>/dev/null || true
        sleep 2
    fi
    
    # Start VM
    log_info "Starting $vm_name VM..."
    if ! limactl start --name="$vm_name" "$config_file" --tty=false; then
        log_error "Failed to start $vm_name"
        RESULTS[$distro]="FAIL"
        return 1
    fi
    
    # Wait for VM to be ready
    sleep 10
    
    # Verify ZFS is installed
    log_info "Verifying ZFS installation..."
    if limactl shell "$vm_name" sudo zfs version >/dev/null 2>&1; then
        log_success "ZFS installed on $distro"
    else
        log_error "ZFS not available on $distro"
        RESULTS[$distro]="FAIL"
        return 1
    fi
    
    # Copy zedlets
    log_info "Copying zedlets to $distro..."
    limactl copy install.sh config.sh zfs-datadog-lib.sh \
        statechange-datadog.sh scrub_start-datadog.sh scrub_finish-datadog.sh \
        resilver_start-datadog.sh resilver_finish-datadog.sh \
        config_sync-datadog.sh pool_import-datadog.sh pool_destroy-datadog.sh \
        vdev_attach-datadog.sh vdev_remove-datadog.sh \
        ereport.fs.zfs.checksum-datadog.sh ereport.fs.zfs.io-datadog.sh \
        checksum-error.sh io-error.sh "$vm_name:/tmp/"
    limactl copy mock-datadog-server.py "$vm_name:/tmp/"
    
    # Test POSIX compatibility
    log_info "Testing POSIX compatibility..."
    if limactl shell "$vm_name" sh -n /tmp/zfs-datadog-lib.sh 2>/dev/null; then
        log_success "POSIX syntax valid on $distro"
    else
        log_error "POSIX syntax errors on $distro"
        RESULTS[$distro]="FAIL"
        return 1
    fi
    
    # Install zedlets
    log_info "Installing zedlets..."
    limactl shell "$vm_name" sudo bash <<'INSTALL'
set -e
cat > /tmp/config.sh <<'CONFIG'
DD_API_KEY="test-key"
DD_API_URL="http://localhost:8080"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:test,distro:${DISTRO}"
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

sleep 2
INSTALL
    
    # Start mock server
    log_info "Starting mock Datadog server..."
    limactl shell "$vm_name" bash <<'START_MOCK'
pkill -f mock-datadog-server.py 2>/dev/null || true
nohup python3 /tmp/mock-datadog-server.py > /tmp/mock-datadog.log 2>&1 &
echo $! > /tmp/mock-datadog.pid
sleep 3
START_MOCK
    
    # Create test pool
    log_info "Creating test pool..."
    limactl shell "$vm_name" sudo bash <<'CREATE_POOL'
mkdir -p /tmp/zfs-test
dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=256 status=none
dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=256 status=none
zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img
zpool status testpool
CREATE_POOL
    
    # Trigger scrub
    log_info "Triggering scrub event..."
    limactl shell "$vm_name" sudo bash <<'TEST_SCRUB'
zpool scrub testpool
while zpool status testpool | grep -q "scan: scrub in progress"; do
    sleep 1
done
sleep 3
TEST_SCRUB
    
    # Check for events
    log_info "Checking for captured events..."
    EVENTS=$(limactl shell "$vm_name" curl -s http://localhost:8080/status 2>/dev/null | jq '.events_received' 2>/dev/null || echo "0")
    
    if [ "$EVENTS" -gt 0 ]; then
        log_success "$distro: $EVENTS events captured"
        RESULTS[$distro]="PASS"
    else
        log_error "$distro: No events captured"
        RESULTS[$distro]="FAIL"
    fi
    
    # Cleanup
    if [ "${KEEP_VMS:-false}" != "true" ]; then
        log_info "Cleaning up $vm_name..."
        limactl stop "$vm_name" 2>/dev/null || true
        limactl delete "$vm_name" 2>/dev/null || true
    fi
}

section "🧪 Multi-Distribution Test Suite"

# Test each distribution
DISTROS=("ubuntu" "debian" "rocky" "fedora" "arch")

for distro in "${DISTROS[@]}"; do
    test_distro "$distro" || true
done

section "📊 Test Results Summary"

echo ""
echo "Distribution Test Results:"
echo "=========================="
for distro in "${DISTROS[@]}"; do
    result="${RESULTS[$distro]:-SKIP}"
    case "$result" in
        PASS) echo -e "  ${GREEN}✓${NC} $distro: PASS" ;;
        FAIL) echo -e "  ${RED}✗${NC} $distro: FAIL" ;;
        SKIP) echo -e "  ${YELLOW}⊘${NC} $distro: SKIP" ;;
    esac
done
echo ""

# Count results
PASSED=0
FAILED=0
SKIPPED=0

for distro in "${DISTROS[@]}"; do
    case "${RESULTS[$distro]:-SKIP}" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        SKIP) SKIPPED=$((SKIPPED + 1)) ;;
    esac
done

echo "Summary:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo "  Skipped: $SKIPPED"
echo ""

if [ $FAILED -eq 0 ] && [ $PASSED -gt 0 ]; then
    log_success "All tested distributions passed!"
    exit 0
else
    log_warning "Some distributions failed or were skipped"
    exit 1
fi
