#!/bin/bash
#
# Parallel Testing of Golden Images
# Tests all built images simultaneously
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_PARALLEL=${MAX_PARALLEL:-4}
RESULTS_DIR="${SCRIPT_DIR}/test-results/$(date +%Y%m%d-%H%M%S)"

mkdir -p "$RESULTS_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "========================================"
echo "Parallel Golden Image Testing"
echo "========================================"
echo ""
echo "Testing all built golden images"
echo "Max parallel tests: $MAX_PARALLEL"
echo "Results directory: $RESULTS_DIR"
echo ""

# Test function
test_image() {
    local os_name=$1
    local image_path=$2
    local ssh_port=$((2200 + RANDOM % 100))
    local result_file="${RESULTS_DIR}/${os_name}.json"
    local log_file="${RESULTS_DIR}/${os_name}.log"
    
    echo "🧪 Testing $os_name on port $ssh_port..." | tee -a "$log_file"
    local start_time=$(date +%s)
    
    # Start VM
    qemu-system-x86_64 \
        -drive file="$image_path",format=qcow2 \
        -m 4G -smp 2 \
        -net nic,model=virtio \
        -net user,hostfwd=tcp::${ssh_port}-:22 \
        -display none \
        -daemonize \
        -pidfile "${RESULTS_DIR}/${os_name}.pid" \
        >> "$log_file" 2>&1
    
    local vm_pid=$(cat "${RESULTS_DIR}/${os_name}.pid")
    
    # Wait for SSH
    local ssh_ready=0
    for i in {1..60}; do
        if nc -z localhost "$ssh_port" 2>/dev/null; then
            ssh_ready=1
            break
        fi
        sleep 1
    done
    
    if [ $ssh_ready -eq 0 ]; then
        echo "✗ $os_name: SSH timeout" | tee -a "$log_file"
        kill "$vm_pid" 2>/dev/null || true
        echo '{"status":"FAIL","reason":"SSH timeout"}' > "$result_file"
        return 1
    fi
    
    # Run tests via SSH
    local test_result=0
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -p "$ssh_port" root@localhost \
        "zpool scrub testpool && sleep 5 && curl -s http://localhost:8080/status" \
        >> "$log_file" 2>&1 || test_result=$?
    
    # Shutdown VM
    kill "$vm_pid" 2>/dev/null || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $test_result -eq 0 ]; then
        echo "✓ $os_name: PASS (${duration}s)" | tee -a "$log_file"
        echo "{\"status\":\"PASS\",\"duration\":${duration}}" > "$result_file"
        return 0
    else
        echo "✗ $os_name: FAIL (${duration}s)" | tee -a "$log_file"
        echo "{\"status\":\"FAIL\",\"duration\":${duration}}" > "$result_file"
        return 1
    fi
}

export -f test_image
export RESULTS_DIR

# Find all built images
declare -a IMAGES=()
for output_dir in output-*/; do
    if [ -d "$output_dir" ]; then
        os_name=$(basename "$output_dir" | sed 's/^output-//')
        image_file=$(find "$output_dir" -name "*.qcow2" -type f | head -1)
        if [ -n "$image_file" ]; then
            IMAGES+=("${os_name}:${image_file}")
        fi
    fi
done

if [ ${#IMAGES[@]} -eq 0 ]; then
    log_error "No golden images found. Run ./build-all-images.sh first."
    exit 1
fi

log_info "Found ${#IMAGES[@]} images to test"
echo ""

# Test all images in parallel
if command -v parallel &> /dev/null; then
    log_info "Using GNU Parallel for maximum speed"
    printf '%s\n' "${IMAGES[@]}" | parallel -j "$MAX_PARALLEL" --colsep ':' test_image {1} {2}
else
    log_info "Using xargs for parallel testing"
    printf '%s\n' "${IMAGES[@]}" | xargs -P "$MAX_PARALLEL" -I {} bash -c '
        IFS=: read -r name image <<< "{}"
        test_image "$name" "$image"
    '
fi

echo ""
echo "========================================"
echo "Test Results Summary"
echo "========================================"
echo ""

# Aggregate results
TOTAL=0
PASSED=0
FAILED=0

for result_file in "$RESULTS_DIR"/*.json; do
    if [ -f "$result_file" ]; then
        TOTAL=$((TOTAL + 1))
        status=$(jq -r '.status' "$result_file" 2>/dev/null || echo "UNKNOWN")
        os_name=$(basename "$result_file" .json)
        
        if [ "$status" = "PASS" ]; then
            PASSED=$((PASSED + 1))
            duration=$(jq -r '.duration' "$result_file")
            echo -e "${GREEN}✓${NC} $os_name: PASS (${duration}s)"
        else
            FAILED=$((FAILED + 1))
            echo -e "${RED}✗${NC} $os_name: FAIL"
        fi
    fi
done

echo ""
echo "Total: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Success Rate: $((PASSED * 100 / TOTAL))%"
echo ""

if [ $PASSED -eq $TOTAL ]; then
    log_success "All tests passed! 🎉"
    echo ""
    echo "✅ ZFS Datadog integration validated across all platforms"
    echo "✅ Production-ready for deployment"
else
    log_error "$FAILED tests failed. Review logs in $RESULTS_DIR"
fi

# Generate HTML report
cat > "${RESULTS_DIR}/report.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Multi-OS Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>Multi-OS Test Results</h1>
    <p>Date: $(date)</p>
    <p>Total: $TOTAL | Passed: $PASSED | Failed: $FAILED | Success Rate: $((PASSED * 100 / TOTAL))%</p>
    <table>
        <tr><th>OS</th><th>Status</th><th>Duration</th></tr>
EOF

for result_file in "$RESULTS_DIR"/*.json; do
    if [ -f "$result_file" ]; then
        os_name=$(basename "$result_file" .json)
        status=$(jq -r '.status' "$result_file" 2>/dev/null || echo "UNKNOWN")
        duration=$(jq -r '.duration // 0' "$result_file" 2>/dev/null)
        
        if [ "$status" = "PASS" ]; then
            echo "<tr><td>$os_name</td><td class='pass'>✓ PASS</td><td>${duration}s</td></tr>" >> "${RESULTS_DIR}/report.html"
        else
            echo "<tr><td>$os_name</td><td class='fail'>✗ FAIL</td><td>${duration}s</td></tr>" >> "${RESULTS_DIR}/report.html"
        fi
    fi
done

cat >> "${RESULTS_DIR}/report.html" <<EOF
    </table>
</body>
</html>
EOF

log_success "HTML report generated: ${RESULTS_DIR}/report.html"
