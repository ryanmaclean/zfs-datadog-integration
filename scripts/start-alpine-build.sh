#!/bin/sh
#
# Start Alpine kernel build (automated with retries)
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VM_NAME="alpine-kernel-build"

echo "${CYAN}═══════════════════════════════════════${NC}"
echo "${CYAN}Alpine M-series Kernel Build - AUTOMATED${NC}"
echo "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Wait for SSH to be ready
echo "${CYAN}Waiting for Alpine VM to be ready...${NC}"
MAX_WAIT=180  # 3 minutes
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if limactl shell "$VM_NAME" -- echo "SSH ready" >/dev/null 2>&1; then
        echo "${GREEN}✓ SSH is ready!${NC}"
        break
    fi
    echo "Waiting... ($ELAPSED/${MAX_WAIT}s)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "${YELLOW}Warning: Timeout waiting for SSH, trying anyway...${NC}"
fi

# Verify it's musl
echo ""
echo "${CYAN}Verifying Alpine + musl...${NC}"
limactl shell "$VM_NAME" -- sh -c 'ldd --version 2>&1 | head -1' || echo "ldd check"
limactl shell "$VM_NAME" -- uname -m

# Copy build files
echo ""
echo "${CYAN}Copying kernel config and build scripts...${NC}"
limactl copy kernels/alpine-m-series.config "$VM_NAME:/tmp/"
limactl copy kernels/build-alpine-kernel.sh "$VM_NAME:/tmp/"
limactl copy kernels/zfs-m-series-tuning.conf "$VM_NAME:/tmp/"

echo "${GREEN}✓ Files copied${NC}"

# Start kernel build
echo ""
echo "${CYAN}Starting kernel build (this takes 20-30 minutes)...${NC}"
echo "${YELLOW}You can monitor progress with:${NC}"
echo "${YELLOW}  limactl shell $VM_NAME${NC}"
echo "${YELLOW}  tail -f /var/log/messages${NC}"
echo ""

limactl shell "$VM_NAME" -- sudo sh -c '
    chmod +x /tmp/build-alpine-kernel.sh
    /tmp/build-alpine-kernel.sh
' || {
    echo "${YELLOW}Build may have issues, check logs${NC}"
    exit 1
}

echo ""
echo "${GREEN}✓ Alpine kernel build complete!${NC}"
echo ""
echo "Artifacts should be in /boot/"
echo "  - vmlinuz-m-series"
echo "  - initramfs-m-series"
echo "  - config-m-series"
