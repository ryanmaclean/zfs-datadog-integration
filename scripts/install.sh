#!/bin/bash
#
# ZFS Datadog Integration Installation Script
# Installs zedlets and configures ZFS Event Daemon
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Detect ZED directory
ZED_DIR="/etc/zfs/zed.d"
if [[ ! -d "$ZED_DIR" ]]; then
    echo -e "${RED}Error: ZED directory not found at $ZED_DIR${NC}"
    echo "Please ensure OpenZFS is installed"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}ZFS Datadog Integration Installer${NC}"
echo "=================================="
echo ""

# Check for required dependencies
echo "Checking dependencies..."
MISSING_DEPS=()

if ! command -v curl &> /dev/null; then
    MISSING_DEPS+=("curl")
fi

if ! command -v nc &> /dev/null; then
    MISSING_DEPS+=("nc (netcat)")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo -e "${RED}Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All dependencies found${NC}"
echo ""

# List of files to install
FILES=(
    "zfs-datadog-lib.sh"
    "config.sh"
    "statechange-datadog.sh"
    "scrub_finish-datadog.sh"
    "resilver_finish-datadog.sh"
    "all-datadog.sh"
    "checksum-error.sh"
    "io-error.sh"
)

# Check if all files exist
echo "Checking source files..."
for file in "${FILES[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
        echo -e "${RED}Error: Missing file $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All source files found${NC}"
echo ""

# Install files
echo "Installing zedlets to $ZED_DIR..."
for file in "${FILES[@]}"; do
    echo "  Installing $file..."
    cp "$SCRIPT_DIR/$file" "$ZED_DIR/"
    chmod 755 "$ZED_DIR/$file"
done

# Set secure permissions on config file
chmod 600 "$ZED_DIR/config.sh"

echo -e "${GREEN}✓ Files installed${NC}"
echo ""

# Check if config has API key
if ! grep -q "DD_API_KEY=.\+" "$ZED_DIR/config.sh" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Warning: DD_API_KEY not configured in config.sh${NC}"
    echo "Please edit $ZED_DIR/config.sh and add your Datadog API key"
    echo ""
fi

# Restart ZED
echo "Restarting ZFS Event Daemon..."
if command -v systemctl &> /dev/null; then
    systemctl restart zfs-zed
    echo -e "${GREEN}✓ ZED restarted via systemctl${NC}"
elif [[ -f /etc/init.d/zfs-zed ]]; then
    /etc/init.d/zfs-zed restart
    echo -e "${GREEN}✓ ZED restarted via init.d${NC}"
else
    echo -e "${YELLOW}⚠ Could not restart ZED automatically${NC}"
    echo "Please restart ZED manually"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Edit $ZED_DIR/config.sh and set your DD_API_KEY"
echo "2. Ensure Datadog Agent is running (for DogStatsD metrics)"
echo "3. Monitor ZED logs: tail -f /var/log/zfs/zed.log"
echo "4. Test by running: zpool scrub <poolname>"
echo ""
echo "For more information, see README.md"
