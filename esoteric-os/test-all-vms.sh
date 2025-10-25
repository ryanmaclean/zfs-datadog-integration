#!/bin/bash
#
# Test Suite for Esoteric Operating Systems
# Tests each VM boots correctly with code-server access
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Esoteric OS Test Suite                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test results
PASSED=0
FAILED=0
SKIPPED=0

test_os() {
    local OS_NAME=$1
    local DESCRIPTION=$2
    
    echo -e "${BLUE}Testing: ${OS_NAME} (${DESCRIPTION})${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Boot VM
    echo "1. Booting VM..."
    if ./boot-esoteric.sh ${OS_NAME} 2>&1 | tee /tmp/${OS_NAME}-boot.log; then
        echo -e "${GREEN}✓ VM booted${NC}"
    else
        echo -e "${RED}✗ VM failed to boot${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # Wait for VM to be ready
    echo "2. Waiting for VM to be ready..."
    sleep 10
    
    # Check VM is running
    echo "3. Checking VM status..."
    if limactl list | grep -q "${OS_NAME}.*Running"; then
        echo -e "${GREEN}✓ VM is running${NC}"
    else
        echo -e "${RED}✗ VM not running${NC}"
        FAILED=$((FAILED + 1))
        limactl stop ${OS_NAME} 2>/dev/null || true
        return 1
    fi
    
    # Get VM IP
    VM_IP=$(limactl shell ${OS_NAME} hostname -I 2>/dev/null | awk '{print $1}')
    echo "VM IP: ${VM_IP}"
    
    # Test code-server
    echo "4. Testing code-server..."
    sleep 5
    if curl -s -o /dev/null -w "%{http_code}" http://${VM_IP}:8080 | grep -q "200\|302"; then
        echo -e "${GREEN}✓ code-server accessible${NC}"
    else
        echo -e "${YELLOW}⚠ code-server not yet ready (may need manual start)${NC}"
    fi
    
    # Test QEMU
    echo "5. Testing QEMU availability..."
    if limactl shell ${OS_NAME} -- which qemu-system-x86_64 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ QEMU installed${NC}"
    else
        echo -e "${RED}✗ QEMU not found${NC}"
        FAILED=$((FAILED + 1))
        limactl stop ${OS_NAME}
        return 1
    fi
    
    # Check ISO downloaded
    echo "6. Checking ISO..."
    if limactl shell ${OS_NAME} -- ls /opt/${OS_NAME}/*.iso >/dev/null 2>&1; then
        ISO_SIZE=$(limactl shell ${OS_NAME} -- du -h /opt/${OS_NAME}/*.iso | awk '{print $1}')
        echo -e "${GREEN}✓ ISO downloaded (${ISO_SIZE})${NC}"
    else
        echo -e "${YELLOW}⚠ ISO not found (may still be downloading)${NC}"
    fi
    
    # Test start script
    echo "7. Testing start script..."
    if limactl shell ${OS_NAME} -- test -x ~/start-${OS_NAME}.sh; then
        echo -e "${GREEN}✓ Start script exists${NC}"
    else
        echo -e "${RED}✗ Start script not found${NC}"
        FAILED=$((FAILED + 1))
        limactl stop ${OS_NAME}
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ ${OS_NAME} test passed!${NC}"
    echo ""
    PASSED=$((PASSED + 1))
    
    # Stop VM (optional)
    echo "Stop VM? (y/N)"
    read -r -n 1 -t 5 STOP_VM || STOP_VM="n"
    echo ""
    if [[ $STOP_VM =~ ^[Yy]$ ]]; then
        limactl stop ${OS_NAME}
        echo -e "${YELLOW}VM stopped${NC}"
    else
        echo -e "${YELLOW}VM left running${NC}"
    fi
    
    echo ""
    return 0
}

# Test each OS
echo "Select OSes to test:"
echo "1. Plan 9 from Bell Labs"
echo "2. Redox OS (Rust)"
echo "3. MINIX 3"
echo "4. Haiku (BeOS)"
echo "5. TempleOS"
echo "6. All of the above"
echo "7. Quick test (Plan 9 only)"
echo ""
read -p "Choice (1-7): " CHOICE

case $CHOICE in
    1)
        test_os "plan9" "Distributed Unix from Bell Labs"
        ;;
    2)
        test_os "redox" "Microkernel OS in Rust"
        ;;
    3)
        test_os "minix" "Microkernel for reliability"
        ;;
    4)
        test_os "haiku" "BeOS spiritual successor"
        ;;
    5)
        test_os "templeos" "Legendary 16-color OS"
        ;;
    6)
        echo "Testing all OSes..."
        test_os "plan9" "Distributed Unix from Bell Labs"
        test_os "redox" "Microkernel OS in Rust"
        test_os "minix" "Microkernel for reliability"
        test_os "haiku" "BeOS spiritual successor"
        test_os "templeos" "Legendary 16-color OS"
        ;;
    7)
        echo "Quick test: Plan 9 only"
        test_os "plan9" "Distributed Unix from Bell Labs"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Summary                                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Passed: ${PASSED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"
echo -e "${YELLOW}Skipped: ${SKIPPED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
