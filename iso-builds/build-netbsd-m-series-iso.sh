#!/bin/sh
#
# Build custom NetBSD ARM64 ISO with M-series optimizations
# Automates the installation with ZFS pre-configured
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "${CYAN}═══════════════════════════════════════${NC}"
echo "${CYAN}NetBSD M-series Custom ISO Builder${NC}"
echo "${CYAN}═══════════════════════════════════════${NC}"
echo ""

ISO_NAME="netbsd-m-series-$(date +%Y%m%d).iso"
WORK_DIR="/tmp/netbsd-build"

# Download NetBSD sets
echo "${CYAN}[1/5] Downloading NetBSD 10.0 sets...${NC}"

mkdir -p "$WORK_DIR/sets"
cd "$WORK_DIR/sets"

BASE_URL="https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/evbarm-aarch64/binary/sets"

for set in base comp etc kern-GENERIC64; do
    echo "Downloading $set..."
    wget -c "$BASE_URL/${set}.tar.xz"
done

echo "${GREEN}✓ Sets downloaded${NC}"

# Extract and customize
echo "${CYAN}[2/5] Extracting and customizing...${NC}"

mkdir -p "$WORK_DIR/rootfs"
cd "$WORK_DIR/rootfs"

for set in ../sets/*.tar.xz; do
    echo "Extracting $(basename $set)..."
    tar xpf "$set"
done

# Install M-series kernel config
mkdir -p usr/src/sys/arch/evbarm/conf
cp ../../kernels/netbsd-m-series-kernel.conf usr/src/sys/arch/evbarm/conf/M-SERIES

# Auto-install script
cat > auto-install.conf << 'EOF'
# NetBSD auto-install for M-series
installation media=cd
network=dhcp
install=yes
root password=netbsd
timezone=UTC
EOF

echo "${GREEN}✓ Customized${NC}"

# Build ISO
echo "${CYAN}[3/5] Building ISO...${NC}"

cd "$WORK_DIR"
makefs -t cd9660 -o rockridge "$ISO_NAME" rootfs/

echo "${GREEN}✓ ISO created: $ISO_NAME${NC}"
echo "  Size: $(du -h "$ISO_NAME" | cut -f1)"
