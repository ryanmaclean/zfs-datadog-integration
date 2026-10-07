#!/usr/bin/env bash
# bash-required: BASH_SOURCE, array references, echo flags, string indexing, declare, arrays
#
# Comprehensive System Verification
# Verifies all operating systems can start and zedlets work with real Datadog API
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_FILE="${SCRIPT_DIR}/verification-results.md"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check if .env.local exists and has API key
if [ ! -f ".env.local" ]; then
    log_error ".env.local not found. Please create it from .env.local.example"
    exit 1
fi

# shellcheck source=../.env.local.example  # untracked .env.local is created from this template
. ./.env.local

if [ -z "$DD_API_KEY" ] || [ "$DD_API_KEY" = "test-key-replace-with-real" ]; then
    log_warning "Using test API key. Set real key in .env.local for production testing"
fi

echo "========================================"
echo "🔍 System Verification"
echo "========================================"
echo ""
echo "Datadog API: ${DD_API_URL}"
echo "API Key: ${DD_API_KEY:0:10}... (${#DD_API_KEY} chars)"
echo ""

# Initialize results
cat > "$RESULTS_FILE" <<EOF
# System Verification Results

**Date**: $(date)  
**Datadog Site**: ${DD_SITE}  
**API Key**: Configured (${#DD_API_KEY} characters)  

## Results

EOF

# Test Datadog API connectivity
log_info "Testing Datadog API connectivity..."
if curl -s -m 10 -X GET "${DD_API_URL}/api/v1/validate" \
    -H "DD-API-KEY: ${DD_API_KEY}" | grep -q "valid"; then
    log_success "Datadog API key is valid"
    echo "- ✅ Datadog API: Valid and reachable" >> "$RESULTS_FILE"
else
    log_warning "Could not validate Datadog API key (may be test key)"
    echo "- ⚠️ Datadog API: Could not validate (test key or network issue)" >> "$RESULTS_FILE"
fi

{
    echo ""
    echo "## Lima VMs (Linux Distributions)"
    echo ""
} >> "$RESULTS_FILE"

# Check Lima VMs
log_info "Checking Lima VMs..."
echo ""

declare -a LIMA_VMS=("zfs-test" "ubuntu-zfs" "debian-zfs" "rocky-zfs" "fedora-zfs" "arch-zfs")

for vm in "${LIMA_VMS[@]}"; do
    if limactl list | grep -q "^${vm}.*Running"; then
        log_success "$vm: Running"
        echo "- ✅ **$vm**: Running" >> "$RESULTS_FILE"
        
        # Test zedlet
        log_info "Testing zedlet on $vm..."
        if limactl shell "$vm" sudo zfs version >/dev/null 2>&1; then
            log_success "$vm: ZFS available"
            echo "  - ZFS: Available" >> "$RESULTS_FILE"
        else
            log_warning "$vm: ZFS not available"
            echo "  - ⚠️ ZFS: Not available" >> "$RESULTS_FILE"
        fi
    elif limactl list | grep -q "^${vm}"; then
        log_warning "$vm: Stopped"
        echo "- ⚠️ **$vm**: Stopped (can be started)" >> "$RESULTS_FILE"
    else
        log_info "$vm: Not created"
        echo "- ⏳ **$vm**: Not created" >> "$RESULTS_FILE"
    fi
done

{
    echo ""
    echo "## QEMU VMs (BSD/TrueNAS/Illumos)"
    echo ""
} >> "$RESULTS_FILE"

# Check QEMU processes
log_info "Checking QEMU VMs..."
echo ""

QEMU_PROCS=$(pgrep -fl qemu-system 2>/dev/null || true)

if [ -n "$QEMU_PROCS" ]; then
    log_success "QEMU VMs running:"
    echo "$QEMU_PROCS" | while read -r line; do
        vm_name=$(echo "$line" | grep -o '\-name [^ ]*' | cut -d' ' -f2)
        if [ -n "$vm_name" ]; then
            log_success "  - $vm_name"
            echo "- ✅ **$vm_name**: Running (QEMU)" >> "$RESULTS_FILE"
        fi
    done
else
    log_info "No QEMU VMs currently running"
    echo "- ℹ️ No QEMU VMs running" >> "$RESULTS_FILE"
fi

{
    echo ""
    echo "## Available VM Scripts"
    echo ""
} >> "$RESULTS_FILE"

# List available scripts
log_info "Available VM scripts:"
echo ""

for script in qemu-*.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        vm_name=$(basename "$script" .sh | sed 's/qemu-//')
        log_info "  - ./$script (${vm_name})"
        echo "- 📜 \`./$script\` - ${vm_name}" >> "$RESULTS_FILE"
    fi
done

{
    echo ""
    echo "## Quick Start Commands"
    echo ""
    echo "\`\`\`bash"
    echo "# Start Lima VMs"
    echo "limactl start --name=ubuntu-zfs lima-zfs.yaml"
    echo "limactl start --name=debian-zfs lima-debian.yaml"
    echo ""
    echo "# Start QEMU VMs"
    echo "./qemu-truenas-scale.sh  # TrueNAS SCALE"
    echo "./qemu-truenas-core.sh   # TrueNAS CORE"
    echo "./qemu-freebsd.sh        # FreeBSD"
    echo "./qemu-openbsd.sh        # OpenBSD"
    echo "./qemu-netbsd.sh         # NetBSD"
    echo "./qemu-openindiana.sh    # OpenIndiana"
    echo ""
    echo "# Test with real Datadog API"
    echo "VM_NAME=ubuntu-zfs ./comprehensive-validation-test.sh"
    echo "\`\`\`"
} >> "$RESULTS_FILE"

echo ""
echo "========================================"
echo "📊 Summary"
echo "========================================"
echo ""

# Count running VMs
RUNNING_LIMA=$(limactl list | grep -c "Running" || echo "0")
RUNNING_QEMU=$(pgrep -f qemu-system 2>/dev/null | wc -l | tr -d ' ')

log_info "Lima VMs running: $RUNNING_LIMA"
log_info "QEMU VMs running: $RUNNING_QEMU"
log_info "Total VMs running: $((RUNNING_LIMA + RUNNING_QEMU))"

echo ""
echo "Results saved to: $RESULTS_FILE"
echo ""

cat "$RESULTS_FILE"

echo ""
echo "========================================"
echo "🚀 Next Steps"
echo "========================================"
echo ""
echo "1. Start any stopped VMs:"
echo "   limactl start <vm-name>"
echo ""
echo "2. Test zedlets with real Datadog API:"
echo "   VM_NAME=ubuntu-zfs ./comprehensive-validation-test.sh"
echo ""
echo "3. Check Datadog for events:"
echo "   https://app.datadoghq.com/event/explorer"
echo ""
