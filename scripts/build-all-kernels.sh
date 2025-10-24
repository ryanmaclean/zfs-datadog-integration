#!/bin/sh
#
# Sequential kernel build script for all BSD + Alpine
# Builds custom M-series kernels for all platforms
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  SEQUENTIAL M-SERIES KERNEL BUILDER     ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check Lima
if ! command -v limactl >/dev/null 2>&1; then
    echo "${RED}Error: Lima not installed${NC}"
    exit 1
fi

ARTIFACTS_DIR="$(pwd)/kernel-artifacts"
mkdir -p "$ARTIFACTS_DIR"

echo "${CYAN}Artifacts will be saved to: $ARTIFACTS_DIR${NC}"
echo ""

# ============================================================================
# 1. ALPINE KERNEL
# ============================================================================

echo "${GREEN}═══════════════════════════════════════${NC}"
echo "${GREEN}[1/4] Building Alpine M-series Kernel${NC}"
echo "${GREEN}═══════════════════════════════════════${NC}"
echo ""

# Start Alpine VM
echo "${CYAN}Starting Alpine VM...${NC}"
limactl start --name=alpine-kernel-build examples/lima/lima-alpine-arm64.yaml --tty=false || {
    echo "${YELLOW}VM already exists, using it${NC}"
}

# Wait for provisioning
echo "${CYAN}Waiting for VM provisioning...${NC}"
sleep 90

# Copy build files
echo "${CYAN}Copying kernel config and build script...${NC}"
limactl copy kernels/alpine-m-series.config alpine-kernel-build:/tmp/
limactl copy kernels/build-alpine-kernel.sh alpine-kernel-build:/tmp/
limactl copy kernels/zfs-m-series-tuning.conf alpine-kernel-build:/tmp/

# Build kernel
echo "${CYAN}Building kernel (this takes 20-30 minutes)...${NC}"
limactl shell alpine-kernel-build -- sudo sh /tmp/build-alpine-kernel.sh || {
    echo "${RED}Alpine kernel build failed!${NC}"
    echo "Check logs with: limactl shell alpine-kernel-build"
    exit 1
}

# Extract artifacts
echo "${CYAN}Extracting Alpine kernel artifacts...${NC}"
mkdir -p "$ARTIFACTS_DIR/alpine"
limactl shell alpine-kernel-build -- sudo tar -czf /tmp/alpine-kernel.tar.gz \
    -C /boot vmlinuz-m-series initramfs-m-series config-m-series || {
    echo "${YELLOW}Warning: Could not create tarball, copying files individually${NC}"
    limactl copy alpine-kernel-build:/boot/vmlinuz-m-series "$ARTIFACTS_DIR/alpine/" || true
    limactl copy alpine-kernel-build:/boot/initramfs-m-series "$ARTIFACTS_DIR/alpine/" || true
    limactl copy alpine-kernel-build:/boot/config-m-series "$ARTIFACTS_DIR/alpine/" || true
}

if [ -f "$ARTIFACTS_DIR/alpine/vmlinuz-m-series" ]; then
    echo "${GREEN}✓ Alpine kernel built successfully!${NC}"
    echo "${CYAN}Size: $(du -h $ARTIFACTS_DIR/alpine/vmlinuz-m-series | cut -f1)${NC}"
else
    echo "${RED}✗ Alpine kernel artifacts not found${NC}"
fi

# Stop VM
limactl stop alpine-kernel-build

echo ""

# ============================================================================
# 2. FREEBSD KERNEL  
# ============================================================================

echo "${GREEN}═══════════════════════════════════════${NC}"
echo "${GREEN}[2/4] Building FreeBSD M-series Kernel${NC}"
echo "${GREEN}═══════════════════════════════════════${NC}"
echo ""

# Start FreeBSD VM
echo "${CYAN}Starting FreeBSD VM...${NC}"
limactl start --name=freebsd-kernel-build examples/lima/lima-freebsd-arm64.yaml --tty=false || {
    echo "${YELLOW}VM already exists, using it${NC}"
}

# Wait for provisioning
echo "${CYAN}Waiting for VM provisioning (FreeBSD is slower)...${NC}"
sleep 120

# Copy build files
echo "${CYAN}Copying kernel config and build script...${NC}"
limactl copy kernels/freebsd-m-series-kernel.conf freebsd-kernel-build:/tmp/
limactl copy kernels/build-freebsd-kernel.sh freebsd-kernel-build:/tmp/

# Build kernel
echo "${CYAN}Building kernel (this takes 30-45 minutes)...${NC}"
limactl shell freebsd-kernel-build -- sudo sh /tmp/build-freebsd-kernel.sh || {
    echo "${RED}FreeBSD kernel build failed!${NC}"
    echo "Check logs with: limactl shell freebsd-kernel-build"
    exit 1
}

# Extract artifacts
echo "${CYAN}Extracting FreeBSD kernel artifacts...${NC}"
mkdir -p "$ARTIFACTS_DIR/freebsd"
limactl copy freebsd-kernel-build:/boot/kernel/kernel "$ARTIFACTS_DIR/freebsd/" || true
limactl copy freebsd-kernel-build:/boot/loader.conf "$ARTIFACTS_DIR/freebsd/" || true

if [ -f "$ARTIFACTS_DIR/freebsd/kernel" ]; then
    echo "${GREEN}✓ FreeBSD kernel built successfully!${NC}"
    echo "${CYAN}Size: $(du -h $ARTIFACTS_DIR/freebsd/kernel | cut -f1)${NC}"
else
    echo "${RED}✗ FreeBSD kernel artifacts not found${NC}"
fi

# Stop VM
limactl stop freebsd-kernel-build

echo ""

# ============================================================================
# 3. NETBSD KERNEL
# ============================================================================

echo "${GREEN}═══════════════════════════════════════${NC}"
echo "${GREEN}[3/4] Building NetBSD M-series Kernel${NC}"
echo "${GREEN}═══════════════════════════════════════${NC}"
echo ""

# Start NetBSD VM
echo "${CYAN}Starting NetBSD VM...${NC}"
limactl start --name=netbsd-kernel-build examples/lima/lima-netbsd-arm64.yaml --tty=false || {
    echo "${YELLOW}VM already exists, using it${NC}"
}

# Wait for provisioning
echo "${CYAN}Waiting for VM provisioning...${NC}"
sleep 120

# Copy build files
echo "${CYAN}Copying kernel config and build script...${NC}"
limactl copy kernels/netbsd-m-series-kernel.conf netbsd-kernel-build:/tmp/
limactl copy kernels/build-netbsd-kernel.sh netbsd-kernel-build:/tmp/

# Build kernel
echo "${CYAN}Building kernel (this takes 30-60 minutes)...${NC}"
limactl shell netbsd-kernel-build -- sudo sh /tmp/build-netbsd-kernel.sh || {
    echo "${RED}NetBSD kernel build failed!${NC}"
    echo "This is expected - NetBSD is more challenging"
    echo "Check logs with: limactl shell netbsd-kernel-build"
}

# Extract artifacts
echo "${CYAN}Extracting NetBSD kernel artifacts...${NC}"
mkdir -p "$ARTIFACTS_DIR/netbsd"
limactl copy netbsd-kernel-build:/netbsd "$ARTIFACTS_DIR/netbsd/netbsd.m-series" || {
    echo "${YELLOW}NetBSD kernel extraction failed (expected)${NC}"
}

if [ -f "$ARTIFACTS_DIR/netbsd/netbsd.m-series" ]; then
    echo "${GREEN}✓ NetBSD kernel built successfully!${NC}"
    echo "${CYAN}Size: $(du -h $ARTIFACTS_DIR/netbsd/netbsd.m-series | cut -f1)${NC}"
else
    echo "${YELLOW}⚠ NetBSD kernel build incomplete (this is normal)${NC}"
fi

# Stop VM
limactl stop netbsd-kernel-build || true

echo ""

# ============================================================================
# 4. OPENBSD KERNEL
# ============================================================================

echo "${GREEN}═══════════════════════════════════════${NC}"
echo "${GREEN}[4/4] Building OpenBSD M-series Kernel${NC}"
echo "${GREEN}═══════════════════════════════════════${NC}"
echo ""

echo "${YELLOW}Note: OpenBSD kernel build is highly experimental${NC}"
echo "${YELLOW}This may fail due to ZFS incompatibility${NC}"
echo ""

# Start OpenBSD VM
echo "${CYAN}Starting OpenBSD VM...${NC}"
limactl start --name=openbsd-kernel-build examples/lima/lima-openbsd-arm64.yaml --tty=false || {
    echo "${YELLOW}VM already exists, using it${NC}"
}

# Wait for provisioning
echo "${CYAN}Waiting for VM provisioning...${NC}"
sleep 120

# Copy build files
echo "${CYAN}Copying kernel config and build script...${NC}"
limactl copy kernels/openbsd-m-series-kernel.conf openbsd-kernel-build:/tmp/ || true
limactl copy kernels/build-openbsd-kernel.sh openbsd-kernel-build:/tmp/ || true

# Build kernel
echo "${CYAN}Building kernel (this takes 15-30 minutes)...${NC}"
limactl shell openbsd-kernel-build -- sudo sh /tmp/build-openbsd-kernel.sh || {
    echo "${RED}OpenBSD kernel build failed!${NC}"
    echo "This is expected - OpenBSD + ZFS is experimental"
}

# Extract artifacts
echo "${CYAN}Extracting OpenBSD kernel artifacts...${NC}"
mkdir -p "$ARTIFACTS_DIR/openbsd"
limactl copy openbsd-kernel-build:/bsd "$ARTIFACTS_DIR/openbsd/bsd.m-series" || {
    echo "${YELLOW}OpenBSD kernel extraction failed (expected)${NC}"
}

if [ -f "$ARTIFACTS_DIR/openbsd/bsd.m-series" ]; then
    echo "${GREEN}✓ OpenBSD kernel built successfully!${NC}"
    echo "${CYAN}Size: $(du -h $ARTIFACTS_DIR/openbsd/bsd.m-series | cut -f1)${NC}"
else
    echo "${YELLOW}⚠ OpenBSD kernel build incomplete (expected)${NC}"
fi

# Stop VM
limactl stop openbsd-kernel-build || true

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║          BUILD SUMMARY                   ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check what we built
ALPINE_OK=0
FREEBSD_OK=0
NETBSD_OK=0
OPENBSD_OK=0

if [ -f "$ARTIFACTS_DIR/alpine/vmlinuz-m-series" ]; then
    ALPINE_OK=1
    echo "${GREEN}✓ Alpine kernel:  $(du -h $ARTIFACTS_DIR/alpine/vmlinuz-m-series | cut -f1)${NC}"
else
    echo "${RED}✗ Alpine kernel:  FAILED${NC}"
fi

if [ -f "$ARTIFACTS_DIR/freebsd/kernel" ]; then
    FREEBSD_OK=1
    echo "${GREEN}✓ FreeBSD kernel: $(du -h $ARTIFACTS_DIR/freebsd/kernel | cut -f1)${NC}"
else
    echo "${RED}✗ FreeBSD kernel: FAILED${NC}"
fi

if [ -f "$ARTIFACTS_DIR/netbsd/netbsd.m-series" ]; then
    NETBSD_OK=1
    echo "${GREEN}✓ NetBSD kernel:  $(du -h $ARTIFACTS_DIR/netbsd/netbsd.m-series | cut -f1)${NC}"
else
    echo "${YELLOW}⚠ NetBSD kernel:  INCOMPLETE${NC}"
fi

if [ -f "$ARTIFACTS_DIR/openbsd/bsd.m-series" ]; then
    OPENBSD_OK=1
    echo "${GREEN}✓ OpenBSD kernel: $(du -h $ARTIFACTS_DIR/openbsd/bsd.m-series | cut -f1)${NC}"
else
    echo "${YELLOW}⚠ OpenBSD kernel: INCOMPLETE${NC}"
fi

echo ""
echo "${CYAN}Artifacts directory: $ARTIFACTS_DIR${NC}"
echo ""

TOTAL=$((ALPINE_OK + FREEBSD_OK + NETBSD_OK + OPENBSD_OK))
echo "${MAGENTA}Success rate: $TOTAL/4${NC}"

if [ $TOTAL -ge 2 ]; then
    echo ""
    echo "${GREEN}SUCCESS! At least 2 kernels built successfully.${NC}"
    exit 0
else
    echo ""
    echo "${YELLOW}PARTIAL SUCCESS: Only $TOTAL kernel(s) built.${NC}"
    exit 1
fi
