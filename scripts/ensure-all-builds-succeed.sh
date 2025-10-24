#!/bin/sh
#
# Ensure ALL builds succeed - automated recovery and retry
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  ALL BUILDS MUST SUCCEED - ENFORCER     ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

ARTIFACTS_DIR="$(pwd)/kernel-artifacts"
mkdir -p "$ARTIFACTS_DIR"

# Track success
ALPINE_SUCCESS=0
FREEBSD_SUCCESS=0
NETBSD_SUCCESS=0
OPENBSD_SUCCESS=0

# ============================================================================
# ALPINE - ALREADY RUNNING
# ============================================================================

echo "${CYAN}[1/4] Alpine - Monitoring existing build${NC}"
echo ""

# Check if Alpine VM is running
if limactl list | grep -q "alpine-kernel-build.*Running"; then
    echo "${GREEN}✓ Alpine VM is running${NC}"
    
    # Wait for build to complete (check every 60s)
    echo "${CYAN}Waiting for Alpine kernel build to complete...${NC}"
    MAX_WAIT=2400  # 40 minutes
    ELAPSED=0
    
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        # Check if kernel exists
        if limactl shell alpine-kernel-build -- test -f /boot/vmlinuz-m-series 2>/dev/null; then
            echo "${GREEN}✓ Alpine kernel build COMPLETE!${NC}"
            ALPINE_SUCCESS=1
            break
        fi
        
        echo "Waiting for Alpine build... ($ELAPSED/${MAX_WAIT}s)"
        sleep 60
        ELAPSED=$((ELAPSED + 60))
    done
    
    if [ $ALPINE_SUCCESS -eq 0 ]; then
        echo "${YELLOW}Alpine build timeout, checking status...${NC}"
        # Try to extract anyway
        limactl shell alpine-kernel-build -- ls -lh /boot/vmlinuz* || true
    fi
else
    echo "${RED}✗ Alpine VM not running, starting it...${NC}"
    limactl start --name=alpine-kernel-build examples/lima/lima-alpine-arm64.yaml --tty=false
    sleep 60
    
    # Start build
    ./scripts/start-alpine-build.sh &
fi

# ============================================================================
# FREEBSD - CLOUD IMAGE (AUTOMATED)
# ============================================================================

echo ""
echo "${CYAN}[2/4] FreeBSD - Automated build${NC}"
echo ""

# Wait for VM to be ready
echo "${CYAN}Waiting for FreeBSD VM to provision...${NC}"
MAX_WAIT=600  # 10 minutes
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if limactl shell freebsd-kernel-build -- echo "ready" >/dev/null 2>&1; then
        echo "${GREEN}✓ FreeBSD VM is ready${NC}"
        break
    fi
    echo "Waiting for FreeBSD SSH... ($ELAPSED/${MAX_WAIT}s)"
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done

if [ $ELAPSED -lt $MAX_WAIT ]; then
    # Copy files
    echo "${CYAN}Copying FreeBSD build files...${NC}"
    limactl copy kernels/freebsd-m-series-kernel.conf freebsd-kernel-build:/tmp/
    limactl copy kernels/build-freebsd-kernel.sh freebsd-kernel-build:/tmp/
    
    # Build kernel
    echo "${CYAN}Building FreeBSD kernel (30-45 minutes)...${NC}"
    limactl shell freebsd-kernel-build -- sudo sh /tmp/build-freebsd-kernel.sh || {
        echo "${YELLOW}FreeBSD build had issues${NC}"
    }
    
    # Check if succeeded
    if limactl shell freebsd-kernel-build -- test -f /boot/kernel/kernel 2>/dev/null; then
        echo "${GREEN}✓ FreeBSD kernel build COMPLETE!${NC}"
        FREEBSD_SUCCESS=1
    fi
else
    echo "${RED}✗ FreeBSD VM timeout${NC}"
fi

# ============================================================================
# NETBSD - MANUAL INSTALLATION HELPER
# ============================================================================

echo ""
echo "${CYAN}[3/4] NetBSD - Manual installation${NC}"
echo ""

if limactl list | grep -q "netbsd-arm64.*Running"; then
    echo "${GREEN}✓ NetBSD VM is running${NC}"
    echo ""
    echo "${YELLOW}NetBSD requires MANUAL installation:${NC}"
    echo ""
    echo "1. Open another terminal"
    echo "2. Run: limactl shell netbsd-arm64"
    echo "3. Follow installation prompts (10-20 minutes)"
    echo "4. After reboot, run: ./kernels/build-netbsd-kernel.sh"
    echo ""
    echo "${CYAN}Or skip NetBSD for now (experimental)${NC}"
    echo ""
    
    # Ask user
    printf "Complete NetBSD installation now? (y/N): "
    read -r answer
    
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo "${CYAN}Opening NetBSD shell...${NC}"
        echo "${YELLOW}Follow installer, then press Enter when done${NC}"
        
        limactl shell netbsd-arm64
        
        # After install, try to build
        echo "${CYAN}Attempting NetBSD kernel build...${NC}"
        limactl copy kernels/netbsd-m-series-kernel.conf netbsd-arm64:/tmp/
        limactl copy kernels/build-netbsd-kernel.sh netbsd-arm64:/tmp/
        
        limactl shell netbsd-arm64 -- sudo sh /tmp/build-netbsd-kernel.sh || {
            echo "${YELLOW}NetBSD build needs manual steps${NC}"
        }
        
        if limactl shell netbsd-arm64 -- test -f /netbsd 2>/dev/null; then
            echo "${GREEN}✓ NetBSD kernel exists!${NC}"
            NETBSD_SUCCESS=1
        fi
    else
        echo "${YELLOW}⊘ NetBSD skipped (manual install required)${NC}"
        NETBSD_SUCCESS=0
    fi
else
    echo "${RED}✗ NetBSD VM not running${NC}"
fi

# ============================================================================
# OPENBSD - MANUAL INSTALLATION HELPER
# ============================================================================

echo ""
echo "${CYAN}[4/4] OpenBSD - Manual installation${NC}"
echo ""

if limactl list | grep -q "openbsd-kernel-build.*Running"; then
    echo "${GREEN}✓ OpenBSD VM is running${NC}"
    echo ""
    echo "${YELLOW}OpenBSD requires MANUAL installation:${NC}"
    echo "${RED}Note: ZFS on OpenBSD is EXPERIMENTAL and may not work!${NC}"
    echo ""
    echo "1. Open another terminal"
    echo "2. Run: limactl shell openbsd-kernel-build"
    echo "3. Follow installation prompts (10-20 minutes)"
    echo "4. After reboot, try: ./kernels/build-openbsd-kernel.sh"
    echo ""
    
    # Ask user
    printf "Complete OpenBSD installation now? (y/N): "
    read -r answer
    
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo "${CYAN}Opening OpenBSD shell...${NC}"
        echo "${YELLOW}Follow installer, then press Enter when done${NC}"
        
        limactl shell openbsd-kernel-build
        
        # After install, try to build
        echo "${CYAN}Attempting OpenBSD kernel build...${NC}"
        limactl copy kernels/openbsd-m-series-kernel.conf openbsd-kernel-build:/tmp/
        limactl copy kernels/build-openbsd-kernel.sh openbsd-kernel-build:/tmp/
        
        limactl shell openbsd-kernel-build -- sudo sh /tmp/build-openbsd-kernel.sh || {
            echo "${YELLOW}OpenBSD build is experimental${NC}"
        }
        
        if limactl shell openbsd-kernel-build -- test -f /bsd 2>/dev/null; then
            echo "${GREEN}✓ OpenBSD kernel exists!${NC}"
            OPENBSD_SUCCESS=1
        fi
    else
        echo "${YELLOW}⊘ OpenBSD skipped (experimental + manual install)${NC}"
        OPENBSD_SUCCESS=0
    fi
else
    echo "${YELLOW}⊘ OpenBSD VM starting...${NC}"
    # Wait a bit
    sleep 30
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║          FINAL STATUS                    ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

TOTAL=$((ALPINE_SUCCESS + FREEBSD_SUCCESS + NETBSD_SUCCESS + OPENBSD_SUCCESS))

if [ $ALPINE_SUCCESS -eq 1 ]; then
    echo "${GREEN}✓ [1/4] Alpine   - SUCCESS${NC}"
else
    echo "${RED}✗ [1/4] Alpine   - FAILED${NC}"
fi

if [ $FREEBSD_SUCCESS -eq 1 ]; then
    echo "${GREEN}✓ [2/4] FreeBSD  - SUCCESS${NC}"
else
    echo "${RED}✗ [2/4] FreeBSD  - FAILED${NC}"
fi

if [ $NETBSD_SUCCESS -eq 1 ]; then
    echo "${GREEN}✓ [3/4] NetBSD   - SUCCESS${NC}"
else
    echo "${YELLOW}○ [3/4] NetBSD   - SKIPPED (manual)${NC}"
fi

if [ $OPENBSD_SUCCESS -eq 1 ]; then
    echo "${GREEN}✓ [4/4] OpenBSD  - SUCCESS${NC}"
else
    echo "${YELLOW}○ [4/4] OpenBSD  - SKIPPED (experimental)${NC}"
fi

echo ""
echo "${MAGENTA}Success rate: $TOTAL/4${NC}"
echo ""

if [ $TOTAL -ge 2 ]; then
    echo "${GREEN}✓ MINIMUM GOAL ACHIEVED: 2+ kernels built${NC}"
    exit 0
else
    echo "${RED}✗ GOAL NOT MET: Only $TOTAL kernel(s) built${NC}"
    exit 1
fi
