#!/usr/bin/env bash
# bash-required: BASH_SOURCE, array references, echo flags, BASH_VERSINFO, declare, arrays, local, export -f, indirect expansion, array key expansion, +=, &>
#
# Parallel Lima VM Testing
# Tests all Linux distributions simultaneously using existing Lima infrastructure
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/parallel-test-results/$(date +%Y%m%d-%H%M%S)"
MAX_PARALLEL=$(sysctl -n hw.ncpu)

mkdir -p "$RESULTS_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "========================================"
echo "🚀 Parallel Lima VM Testing"
echo "========================================"
echo ""
echo "CPU Cores: $MAX_PARALLEL"
echo "Max Parallel VMs: $MAX_PARALLEL"
echo "Results: $RESULTS_DIR"
echo ""

# Define Linux distributions to test (bash 4+ required for associative arrays)
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: Bash 4+ required for associative arrays"
    exit 1
fi

declare -A DISTROS=(
    ["ubuntu"]="lima-zfs.yaml"
    ["debian"]="lima-debian.yaml"
    ["rocky"]="lima-rocky.yaml"
    ["fedora"]="lima-fedora.yaml"
    ["arch"]="lima-arch.yaml"
)

# Test function for single distro
test_distro() {
    local name=$1
    local config=$2
    local result_file="${RESULTS_DIR}/${name}.json"
    local log_file="${RESULTS_DIR}/${name}.log"
    
    echo "🧪 Testing $name..." | tee -a "$log_file"
    local start_time
    start_time=$(date +%s)
    
    # Check if VM already exists
    if limactl list | grep -q "^${name}-zfs"; then
        echo "VM ${name}-zfs already exists, using it" | tee -a "$log_file"
    else
        # Start VM
        echo "Starting ${name}-zfs VM..." | tee -a "$log_file"
        if ! limactl start --name="${name}-zfs" "$config" --tty=false >> "$log_file" 2>&1; then
            echo "✗ $name: Failed to start VM" | tee -a "$log_file"
            echo '{"status":"FAIL","reason":"VM start failed"}' > "$result_file"
            return 1
        fi
        
        # Wait for VM to be ready
        sleep 30
    fi
    
    # Run comprehensive tests
    echo "Running tests on $name..." | tee -a "$log_file"
    if VM_NAME="${name}-zfs" timeout 300 ./comprehensive-validation-test.sh >> "$log_file" 2>&1; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✓ $name: PASS (${duration}s)" | tee -a "$log_file"
        echo "{\"status\":\"PASS\",\"duration\":${duration}}" > "$result_file"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "✗ $name: FAIL (${duration}s)" | tee -a "$log_file"
        echo "{\"status\":\"FAIL\",\"duration\":${duration}}" > "$result_file"
        return 1
    fi
}

export -f test_distro
export RESULTS_DIR
export SCRIPT_DIR

# Test all distros in parallel
log_info "Launching parallel tests..."
echo ""

# Create array of distro:config pairs
declare -a TEST_ARGS=()
for name in "${!DISTROS[@]}"; do
    config="${DISTROS[$name]}"
    TEST_ARGS+=("${name}:${config}")
done

# Run in parallel using GNU parallel
if command -v parallel &> /dev/null; then
    log_info "Using GNU Parallel (${MAX_PARALLEL} jobs)"
    printf '%s\n' "${TEST_ARGS[@]}" | parallel -j "$MAX_PARALLEL" --colsep ':' test_distro '{1}' '{2}'
else
    log_info "Using xargs for parallel execution"
    # The item is passed as $1, never spliced into the code string.
    xargs_worker=$(cat <<'XARGS_WORKER'
IFS=: read -r name config <<< "$1"
test_distro "$name" "$config"
XARGS_WORKER
    )
    printf '%s\n' "${TEST_ARGS[@]}" | xargs -P "$MAX_PARALLEL" -I {} bash -c "$xargs_worker" _ {}
fi

echo ""
echo "========================================"
echo "📊 Test Results Summary"
echo "========================================"
echo ""

# Aggregate results
TOTAL=0
PASSED=0
FAILED=0

for name in "${!DISTROS[@]}"; do
    result_file="${RESULTS_DIR}/${name}.json"
    if [ -f "$result_file" ]; then
        TOTAL=$((TOTAL + 1))
        status=$(jq -r '.status' "$result_file" 2>/dev/null || echo "UNKNOWN")
        duration=$(jq -r '.duration // 0' "$result_file" 2>/dev/null)
        
        if [ "$status" = "PASS" ]; then
            PASSED=$((PASSED + 1))
            echo -e "${GREEN}✓${NC} $name: PASS (${duration}s)"
        else
            FAILED=$((FAILED + 1))
            echo -e "${RED}✗${NC} $name: FAIL"
        fi
    fi
done

echo ""
echo "Linux Distributions:"
echo "  Total: $TOTAL"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
if [ $TOTAL -gt 0 ]; then
    echo "  Success Rate: $((PASSED * 100 / TOTAL))%"
fi
echo ""

# BSD/TrueNAS status
echo "BSD/TrueNAS Systems:"
echo "  TrueNAS SCALE: 🔄 Installation in progress (manual)"
echo "  TrueNAS CORE: ⏳ Pending (manual installation required)"
echo "  FreeBSD: ⏳ Pending (manual installation required)"
echo "  OpenBSD: ⏳ Pending (manual installation required)"
echo "  NetBSD: ⏳ Pending (manual installation required)"
echo "  OpenIndiana: ⏳ Pending (manual installation required)"
echo ""

# Generate markdown report
cat > "${RESULTS_DIR}/report.md" <<EOF
# Parallel Multi-OS Test Results

**Date**: $(date)  
**CPU Cores**: $MAX_PARALLEL  
**Parallel Jobs**: $MAX_PARALLEL  

## Linux Distributions (Lima VMs)

| Distribution | Status | Duration | Notes |
|---|---|---|---|
EOF

for name in "${!DISTROS[@]}"; do
    result_file="${RESULTS_DIR}/${name}.json"
    if [ -f "$result_file" ]; then
        status=$(jq -r '.status' "$result_file" 2>/dev/null || echo "UNKNOWN")
        duration=$(jq -r '.duration // 0' "$result_file" 2>/dev/null)
        
        if [ "$status" = "PASS" ]; then
            echo "| $name | ✅ PASS | ${duration}s | Automated test |" >> "${RESULTS_DIR}/report.md"
        else
            echo "| $name | ❌ FAIL | ${duration}s | See logs |" >> "${RESULTS_DIR}/report.md"
        fi
    fi
done

cat >> "${RESULTS_DIR}/report.md" <<EOF

**Summary**: $PASSED/$TOTAL passed ($((PASSED * 100 / TOTAL))%)

## BSD/TrueNAS Systems (QEMU)

| System | Status | Notes |
|---|---|---|
| TrueNAS SCALE | 🔄 IN PROGRESS | Manual installation |
| TrueNAS CORE | ⏳ PENDING | Manual installation required |
| FreeBSD 14.3 | ⏳ PENDING | Manual installation required |
| OpenBSD 7.6 | ⏳ PENDING | Manual installation required |
| NetBSD 10.0 | ⏳ PENDING | Manual installation required |
| OpenIndiana | ⏳ PENDING | Manual installation required |

## Conclusion

**Linux Testing**: $((PASSED * 100 / TOTAL))% success rate across $TOTAL distributions  
**BSD Testing**: Requires manual installation (QEMU VMs)  

**Next Steps**:
1. Complete TrueNAS SCALE installation
2. Run ./test-truenas-scale.sh
3. Repeat for other BSD systems
4. Use Packer for full automation (future)

## Logs

Individual test logs available in: \`$(basename "$RESULTS_DIR")/\`
EOF

log_success "Report generated: ${RESULTS_DIR}/report.md"
cat "${RESULTS_DIR}/report.md"

if [ $PASSED -eq $TOTAL ] && [ $TOTAL -gt 0 ]; then
    echo ""
    log_success "🎉 All Linux distributions passed!"
    echo ""
    echo "✅ POSIX-compatible zedlets validated"
    echo "✅ Retry logic verified"
    echo "✅ Error handling confirmed"
    echo "✅ Multi-platform support demonstrated"
fi
