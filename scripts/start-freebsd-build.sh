#!/bin/sh
#
# Start FreeBSD kernel build (automated)
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VM_NAME="freebsd-kernel-build"

echo "${CYAN}═══════════════════════════════════════${NC}"
echo "${CYAN}FreeBSD M-series Kernel Build${NC}"
echo "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Wait for SSH
echo "${CYAN}Waiting for FreeBSD VM to be ready...${NC}"
MAX_WAIT=300
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if limactl shell "$VM_NAME" -- echo "ready" >/dev/null 2>&1; then
        echo "${GREEN}✓ SSH ready!${NC}"
        break
    fi
    echo "Waiting... ($ELAPSED/${MAX_WAIT}s)"
    sleep 15
    ELAPSED=$((ELAPSED + 15))
done

# Verify FreeBSD + ZFS
echo ""
echo "${CYAN}Verifying FreeBSD + native ZFS...${NC}"
limactl shell "$VM_NAME" -- uname -a
limactl shell "$VM_NAME" -- zpool version | head -3

# Copy files
echo ""
echo "${CYAN}Copying kernel config and build script...${NC}"
limactl copy kernels/freebsd-m-series-kernel.conf "$VM_NAME:/tmp/"
limactl copy kernels/build-freebsd-kernel.sh "$VM_NAME:/tmp/"

echo "${GREEN}✓ Files copied${NC}"

# Build kernel
echo ""
echo "${CYAN}Starting kernel build (30-45 minutes)...${NC}"
echo "${YELLOW}Monitor with: limactl shell $VM_NAME${NC}"
echo ""

limactl shell "$VM_NAME" -- sudo sh -c '
    chmod +x /tmp/build-freebsd-kernel.sh
    /tmp/build-freebsd-kernel.sh
' || {
    echo "${YELLOW}Build encountered issues${NC}"
    exit 1
}

echo ""
echo "${GREEN}✓ FreeBSD kernel build complete!${NC}"
echo ""
echo "Artifacts in /boot/kernel/"
