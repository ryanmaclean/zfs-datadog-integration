#!/bin/bash
#
# Benchmark VM Startup Times
# Tests FreeBSD, TrueNAS SCALE, and TrueNAS CORE
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_FILE="${SCRIPT_DIR}/vm-benchmark-results.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_benchmark() { echo -e "${CYAN}[BENCHMARK]${NC} $1"; }

# Clear results file
cat > "$RESULTS_FILE" <<EOF
VM Startup Time Benchmarks
===========================
Date: $(date)
Architecture: $(uname -m)
System: $(uname -s) $(uname -r)

EOF

benchmark_vm() {
    local vm_name=$1
    local script=$2
    
    log_info "Benchmarking $vm_name..."
    
    # Record start time
    local start_time=$(date +%s)
    
    # Start VM in background
    log_info "Starting $script..."
    
    # Download/setup phase
    if [[ "$script" == *"freebsd"* ]]; then
        # FreeBSD downloads and extracts image
        log_info "Downloading FreeBSD image (if needed)..."
        timeout 300 bash -c "
            source $script 2>&1 | grep -E 'Downloading|Extracting|Starting' || true
        " &
        local pid=$!
    elif [[ "$script" == *"truenas-scale"* ]]; then
        # TrueNAS SCALE downloads ISO
        log_info "Downloading TrueNAS SCALE ISO (if needed)..."
        timeout 600 bash -c "
            source $script 2>&1 | grep -E 'Downloading|Creating|Starting' || true
        " &
        local pid=$!
    else
        # TrueNAS CORE downloads ISO
        log_info "Downloading TrueNAS CORE ISO (if needed)..."
        timeout 600 bash -c "
            source $script 2>&1 | grep -E 'Downloading|Creating|Starting' || true
        " &
        local pid=$!
    fi
    
    # Wait for download/setup
    wait $pid 2>/dev/null || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_benchmark "$vm_name setup completed in ${duration}s"
    
    # Record results
    cat >> "$RESULTS_FILE" <<EOF

$vm_name
--------
Setup Time: ${duration}s
Script: $script
Status: Setup completed (VM ready to boot)

EOF
    
    echo "$duration"
}

log_info "Starting VM benchmarks..."
echo ""

# Benchmark FreeBSD
log_info "=== FreeBSD 14.2 Benchmark ==="
FREEBSD_TIME=$(benchmark_vm "FreeBSD 14.2" "./qemu-freebsd.sh")

# Benchmark TrueNAS SCALE
log_info "=== TrueNAS SCALE Benchmark ==="
SCALE_TIME=$(benchmark_vm "TrueNAS SCALE 24.04" "./qemu-truenas-scale.sh")

# Benchmark TrueNAS CORE
log_info "=== TrueNAS CORE Benchmark ==="
CORE_TIME=$(benchmark_vm "TrueNAS CORE 13.3" "./qemu-truenas-core.sh")

# Summary
cat >> "$RESULTS_FILE" <<EOF

Summary
=======
FreeBSD 14.2:        ${FREEBSD_TIME}s
TrueNAS SCALE 24.04: ${SCALE_TIME}s
TrueNAS CORE 13.3:   ${CORE_TIME}s

Notes:
- Times include image download (if not cached)
- Actual boot time will be additional
- ARM64 native vs x86_64 emulation affects performance
- First run will be slower due to downloads

EOF

log_success "Benchmark complete!"
log_info "Results saved to: $RESULTS_FILE"
cat "$RESULTS_FILE"
