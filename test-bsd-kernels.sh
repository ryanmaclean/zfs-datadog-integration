#!/bin/bash
#
# Test BSD Kernel Builds and VMs
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  BSD Kernel Build & VM Test Suite                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test results
PASSED=0
FAILED=0

test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ $1${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo "Select test:"
echo "1. Test existing kernel-build VM"
echo "2. Test existing kernel-extract VM"
echo "3. Build minimal Linux kernel (quick test)"
echo "4. Set up FreeBSD kernel build"
echo "5. Test BSD support in ML extension"
echo "6. All of the above"
echo ""
read -p "Choice (1-6): " CHOICE

case $CHOICE in
    1|6)
        echo ""
        echo -e "${BLUE}Testing kernel-build VM...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check if VM exists
        echo "1. Checking if VM exists..."
        limactl list | grep -q "kernel-build"
        test_result "VM exists"
        
        # Check if VM is running
        echo "2. Checking if VM is running..."
        limactl list | grep "kernel-build" | grep -q "Running"
        test_result "VM is running"
        
        # Check resources
        echo "3. Checking VM resources..."
        limactl shell kernel-build -- "nproc && free -h && df -h /" 2>&1 | head -10
        test_result "Resources accessible"
        
        # Check build tools
        echo "4. Checking build tools..."
        limactl shell kernel-build -- "which gcc make" >/dev/null 2>&1
        test_result "Build tools installed"
        
        echo ""
        ;;
esac

case $CHOICE in
    2|6)
        echo ""
        echo -e "${BLUE}Testing kernel-extract VM...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check if VM exists
        echo "1. Checking if VM exists..."
        limactl list | grep -q "kernel-extract"
        test_result "VM exists"
        
        # Check if VM is running
        echo "2. Checking if VM is running..."
        limactl list | grep "kernel-extract" | grep -q "Running"
        test_result "VM is running"
        
        # Check resources
        echo "3. Checking VM resources..."
        limactl shell kernel-extract -- "nproc && free -h && df -h /" 2>&1 | head -10
        test_result "Resources accessible"
        
        echo ""
        ;;
esac

case $CHOICE in
    3|6)
        echo ""
        echo -e "${BLUE}Building minimal Linux kernel (test)...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "This will take ~5 minutes"
        echo ""
        
        # Install build dependencies
        echo "1. Installing build dependencies..."
        limactl shell kernel-build -- "
            sudo apt-get update -qq
            sudo apt-get install -y -qq build-essential libncurses-dev bison flex libssl-dev libelf-dev bc wget
        " 2>&1 | tail -5
        test_result "Dependencies installed"
        
        # Download minimal kernel
        echo "2. Downloading Linux kernel..."
        limactl shell kernel-build -- "
            cd /tmp
            if [ ! -f linux-6.6.tar.xz ]; then
                wget -q --show-progress https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
            fi
            tar -xf linux-6.6.tar.xz 2>/dev/null || true
        " 2>&1 | tail -3
        test_result "Kernel source downloaded"
        
        # Configure minimal kernel
        echo "3. Configuring minimal kernel..."
        limactl shell kernel-build -- "
            cd /tmp/linux-6.6
            make tinyconfig >/dev/null 2>&1
        "
        test_result "Kernel configured"
        
        # Build kernel (quick)
        echo "4. Building kernel (this takes ~5 minutes)..."
        echo "   Starting at: $(date)"
        START_TIME=$(date +%s)
        
        limactl shell kernel-build -- "
            cd /tmp/linux-6.6
            time make -j\$(nproc) 2>&1 | tail -20
        "
        
        END_TIME=$(date +%s)
        BUILD_TIME=$((END_TIME - START_TIME))
        
        if [ -f /tmp/linux-6.6/arch/x86/boot/bzImage ] || limactl shell kernel-build -- "test -f /tmp/linux-6.6/arch/x86/boot/bzImage"; then
            echo -e "${GREEN}✓ Kernel built successfully in ${BUILD_TIME}s${NC}"
            PASSED=$((PASSED + 1))
            
            # Show kernel size
            echo ""
            echo "Kernel details:"
            limactl shell kernel-build -- "ls -lh /tmp/linux-6.6/arch/x86/boot/bzImage"
        else
            echo -e "${RED}✗ Kernel build failed${NC}"
            FAILED=$((FAILED + 1))
        fi
        
        echo ""
        ;;
esac

case $CHOICE in
    4|6)
        echo ""
        echo -e "${BLUE}Setting up FreeBSD kernel build...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Note: Full FreeBSD build takes 2-4 hours"
        echo "This will just set up the environment"
        echo ""
        
        # Install FreeBSD build dependencies
        echo "1. Installing FreeBSD build tools..."
        limactl shell kernel-build -- "
            sudo apt-get install -y -qq git subversion
        " 2>&1 | tail -3
        test_result "FreeBSD tools installed"
        
        # Clone FreeBSD source (shallow)
        echo "2. Cloning FreeBSD source (shallow)..."
        limactl shell kernel-build -- "
            if [ ! -d /tmp/freebsd-src ]; then
                git clone --depth 1 https://git.freebsd.org/src.git /tmp/freebsd-src
            fi
        " 2>&1 | tail -5
        test_result "FreeBSD source cloned"
        
        # Check source
        echo "3. Verifying FreeBSD source..."
        limactl shell kernel-build -- "
            cd /tmp/freebsd-src
            ls -la | head -20
        " 2>&1 | tail -10
        test_result "FreeBSD source verified"
        
        echo ""
        echo -e "${YELLOW}FreeBSD kernel build environment ready${NC}"
        echo "To build FreeBSD kernel:"
        echo "  limactl shell kernel-build"
        echo "  cd /tmp/freebsd-src"
        echo "  sudo make -j\$(nproc) buildkernel"
        echo ""
        ;;
esac

case $CHOICE in
    5|6)
        echo ""
        echo -e "${BLUE}Testing BSD support in ML extension...${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check if extension exists
        echo "1. Checking ML extension..."
        if [ -d "code-app-ml-extension" ]; then
            echo -e "${GREEN}✓ ML extension found${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}✗ ML extension not found${NC}"
            FAILED=$((FAILED + 1))
        fi
        
        # Check BSD documentation
        echo "2. Checking BSD documentation..."
        if [ -f "code-app-ml-extension/BSD-OMNIOS-SUPPORT.md" ]; then
            echo -e "${GREEN}✓ BSD documentation exists${NC}"
            PASSED=$((PASSED + 1))
            
            echo ""
            echo "BSD platforms supported:"
            grep "^-" code-app-ml-extension/BSD-OMNIOS-SUPPORT.md | head -10
        else
            echo -e "${RED}✗ BSD documentation not found${NC}"
            FAILED=$((FAILED + 1))
        fi
        
        # Check if extension is portable
        echo "3. Checking extension portability..."
        if grep -q "Pure JavaScript" code-app-ml-extension/README.md 2>/dev/null; then
            echo -e "${GREEN}✓ Extension is portable (Pure JavaScript)${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${YELLOW}⚠ Portability not documented${NC}"
        fi
        
        echo ""
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
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Build full Linux kernel: limactl shell kernel-build"
    echo "  - Build FreeBSD kernel: cd /tmp/freebsd-src && make buildkernel"
    echo "  - Test on BSD: Deploy to FreeBSD/OpenBSD/NetBSD"
    echo ""
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check VM status: limactl list"
    echo "  - Restart VM: limactl stop kernel-build && limactl start kernel-build"
    echo "  - View logs: limactl shell kernel-build -- dmesg"
    echo ""
    exit 1
fi
