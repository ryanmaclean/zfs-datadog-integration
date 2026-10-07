#!/bin/sh
#
# Test esoteric ARM64 builds with ZFS
# Supports: FreeBSD, NetBSD, OpenBSD on ARM64
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  ESOTERIC ARM64 + ZFS BUILD TESTER      ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check if Lima is installed
if ! command -v limactl >/dev/null 2>&1; then
    echo "${RED}Error: Lima is not installed${NC}"
    echo "Install with: brew install lima"
    exit 1
fi

# Check architecture
ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
    echo "${YELLOW}Warning: You're on $ARCH architecture${NC}"
    echo "ARM64 builds will use emulation (slower)"
    echo ""
fi

echo "${CYAN}Select your esoteric build:${NC}"
echo ""
echo "${GREEN}1)${NC} ${MAGENTA}Alpine Linux ARM64${NC} ${CYAN}(musl + M-series optimized!)${NC}"
echo "   ${BLUE}★${NC} musl libc (not glibc!) - catches portability issues"
echo "   ${BLUE}★${NC} VZ backend - 2x faster than QEMU"
echo "   ${BLUE}★${NC} Lightweight and fast"
echo "   ${BLUE}★${NC} Best performance + esoteric combo"
echo ""
echo "${GREEN}2)${NC} ${MAGENTA}FreeBSD 14.0 ARM64${NC} ${CYAN}(ZED integration unavailable here)${NC}"
echo "   ${BLUE}★${NC} Base FreeBSD uses zfsd/devd; this helper cannot deploy native event delivery"
echo "   ${BLUE}★${NC} Native ZFS built into kernel"
echo "   ${BLUE}★${NC} Excellent ARM64 support"
echo ""
echo "${YELLOW}3)${NC} ${MAGENTA}NetBSD 10.0 ARM64${NC} ${CYAN}(Esoteric, decent ZFS)${NC}"
echo "   ${BLUE}★${NC} Moderately rare combo"
echo "   ${BLUE}★${NC} ZFS works but not as polished"
echo "   ${BLUE}★${NC} Good ARM64 support"
echo ""
echo "${RED}4)${NC} ${MAGENTA}OpenBSD 7.6 ARM64${NC} ${CYAN}(ULTRA ESOTERIC!)${NC}"
echo "   ${BLUE}★${NC} Most exotic - ZFS is experimental"
echo "   ${BLUE}★${NC} May not work at all"
echo "   ${BLUE}★${NC} For the truly adventurous"
echo ""
printf "Choose (1-4): "
read -r choice

case "$choice" in
    1)
        VM_NAME="alpine-arm64"
        LIMA_FILE="examples/lima/lima-alpine-arm64.yaml"
        OS_NAME="Alpine Linux ARM64 (musl)"
        DIFFICULTY="${GREEN}Easy + Esoteric${NC}"
        ;;
    2)
        printf 'Error: FreeBSD native ZFS event delivery is not installed by this ZED test helper.\n' >&2
        printf 'No VM, ZED files, or ZFS services were changed.\n' >&2
        exit 1
        ;;
    3)
        VM_NAME="netbsd-arm64"
        LIMA_FILE="examples/lima/lima-netbsd-arm64.yaml"
        OS_NAME="NetBSD 10.0 ARM64"
        DIFFICULTY="${YELLOW}Medium${NC}"
        ;;
    4)
        VM_NAME="openbsd-arm64"
        LIMA_FILE="examples/lima/lima-openbsd-arm64.yaml"
        OS_NAME="OpenBSD 7.6 ARM64"
        DIFFICULTY="${RED}EXTREME${NC}"
        ;;
    *)
        echo "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "${MAGENTA}═══════════════════════════════════════${NC}"
echo "${CYAN}Selected:${NC} $OS_NAME"
echo "${CYAN}Difficulty:${NC} $DIFFICULTY"
echo "${MAGENTA}═══════════════════════════════════════${NC}"
echo ""

# Check if VM already exists
if limactl list | grep -q "^$VM_NAME"; then
    echo "${YELLOW}VM '$VM_NAME' already exists${NC}"
    printf "Delete and recreate? (y/N): "
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "${CYAN}Stopping and deleting VM...${NC}"
        limactl stop "$VM_NAME" 2>/dev/null || true
        limactl delete "$VM_NAME" 2>/dev/null || true
    else
        echo "${CYAN}Using existing VM${NC}"
    fi
fi

# Start VM
echo ""
echo "${CYAN}Starting $OS_NAME VM...${NC}"
echo "This may take several minutes..."
echo ""

if ! limactl list | grep -q "^$VM_NAME"; then
    limactl start --name="$VM_NAME" "$LIMA_FILE" || {
        echo "${RED}Failed to start VM${NC}"
        echo ""
        echo "${YELLOW}Troubleshooting:${NC}"
        echo "1. Check Lima logs: limactl list"
        echo "2. Try: limactl delete $VM_NAME"
        echo "3. Retry the script"
        exit 1
    }
fi

echo ""
echo "${GREEN}✓ VM started successfully!${NC}"
echo ""

# Wait for VM to be ready
echo "${CYAN}Waiting for VM to be ready...${NC}"
sleep 5

# Test ZFS
echo ""
echo "${CYAN}Testing ZFS functionality...${NC}"
echo ""

limactl shell "$VM_NAME" -- sh -c '
    echo "=== System Info ==="
    uname -a
    echo ""
    
    echo "=== ZFS Version ==="
    if command -v zpool >/dev/null 2>&1; then
        zpool version
        zfs version
        echo ""
        echo "✓ ZFS is available!"
    else
        echo "✗ ZFS not found"
        exit 1
    fi
    
    echo ""
    echo "=== ZFS Pools ==="
    zpool list || echo "No pools found"
    
    echo ""
    echo "=== ZFS Datasets ==="
    zfs list || echo "No datasets found"
' || {
    echo "${RED}Failed to test ZFS in VM${NC}"
    exit 1
}

echo ""
echo "${GREEN}✓ ZFS test completed!${NC}"
echo ""

# Native event delivery for this selected OS is not verified.
printf 'ZFS VM test passed; Datadog ZFS deployment is blocked until a native event route is proven for %s.\n' "$OS_NAME" >&2
exit 1
