#!/bin/sh
#
# Build custom OpenBSD ARM64 ISO with auto-install
# Makes the experimental ZFS + OpenBSD combo easier
#

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "${CYAN}═══════════════════════════════════════${NC}"
echo "${CYAN}OpenBSD M-series Custom ISO Builder${NC}"
echo "${CYAN}(Experimental ZFS support)${NC}"
echo "${CYAN}═══════════════════════════════════════${NC}"
echo ""

ISO_NAME="openbsd-m-series-$(date +%Y%m%d).iso"
WORK_DIR="/tmp/openbsd-build"

# Download OpenBSD base
echo "${CYAN}[1/4] Downloading OpenBSD 7.6 ARM64...${NC}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

wget -c https://cdn.openbsd.org/pub/OpenBSD/7.6/arm64/base76.tgz
wget -c https://cdn.openbsd.org/pub/OpenBSD/7.6/arm64/comp76.tgz
wget -c https://cdn.openbsd.org/pub/OpenBSD/7.6/arm64/bsd

echo "${GREEN}✓ Downloaded${NC}"

# Extract and customize
echo "${CYAN}[2/4] Customizing...${NC}"

mkdir -p rootfs
cd rootfs
tar xzf ../base76.tgz
tar xzf ../comp76.tgz

# Auto-install config
cat > auto_install.conf << 'EOF'
System hostname = openbsd-m-series
Password for root account = openbsd
Network interfaces = vio0
IPv4 address for vio0 = dhcp
Setup a user = no
Which disk is the root disk = sd0
Use (W)hole disk or (E)dit the MBR = W
Use (A)uto layout or (E)dit = A
Location of sets = cd
Set name(s) = done
EOF

echo "${GREEN}✓ Customized${NC}"

# Note about ZFS
cat > README.ZFS << 'EOF'
# ZFS on OpenBSD is EXPERIMENTAL

OpenBSD does not officially support ZFS due to license conflicts.

To attempt ZFS anyway:
1. Boot this ISO
2. Complete installation
3. Compile OpenZFS from ports (if available)
4. Good luck!

This is for brave souls only.
EOF

echo "${CYAN}[3/4] Creating ISO...${NC}"
# Create ISO with auto-install
