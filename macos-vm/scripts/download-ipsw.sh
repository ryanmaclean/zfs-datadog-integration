#!/bin/bash
#
# Download macOS IPSW for VM creation
# Detects architecture and downloads appropriate IPSW
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  macOS IPSW Downloader                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
echo -e "${GREEN}Detected architecture:${NC} $ARCH"
echo ""

# Create download directory
IPSW_DIR="$(dirname "$0")/../ipsw"
mkdir -p "$IPSW_DIR"

# Determine IPSW URL based on architecture
if [ "$ARCH" = "arm64" ]; then
    echo -e "${YELLOW}Note: IPSW URLs change frequently!${NC}"
    echo ""
    echo "This script will guide you to download the IPSW manually."
    echo ""
    echo "IPSW files are large (13-15GB) and may take 10-30 minutes"
    echo ""
    
    # Manual download instructions
    echo -e "${BLUE}Manual Download Steps:${NC}"
    echo ""
    echo "1. Open: https://ipsw.me"
    echo "2. Select: Mac"
    echo "3. Choose your Mac model (M1/M2/M3)"
    echo "4. Download latest macOS IPSW"
    echo "5. Save to: $IPSW_DIR/"
    echo ""
    echo -e "${YELLOW}Opening ipsw.me in browser...${NC}"
    sleep 2
    open "https://ipsw.me" 2>/dev/null || echo "Visit: https://ipsw.me"
    echo ""
    echo "After downloading, move the IPSW file to:"
    echo "  $IPSW_DIR/"
    echo ""
    echo "Then run this script again to verify."
    echo ""
    exit 0
    
elif [ "$ARCH" = "x86_64" ]; then
    echo -e "${YELLOW}Intel Macs cannot run macOS VMs via Lima${NC}"
    echo ""
    echo "Alternatives:"
    echo "1. Use VMware Fusion or Parallels Desktop"
    echo "2. Use VirtualBox (limited support)"
    echo "3. Use a cloud macOS instance"
    echo ""
    exit 1
else
    echo -e "${RED}Unknown architecture: $ARCH${NC}"
    exit 1
fi

# Check if already downloaded
if [ -f "$IPSW_FILE" ]; then
    echo -e "${YELLOW}IPSW already exists:${NC} $IPSW_FILE"
    echo ""
    read -p "Re-download? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing IPSW${NC}"
        echo ""
        ls -lh "$IPSW_FILE"
        exit 0
    fi
    rm -f "$IPSW_FILE"
fi

# Check disk space (macOS compatible)
REQUIRED_SPACE=20  # GB
AVAILABLE_SPACE=$(df -g "$IPSW_DIR" | awk 'NR==2 {print $4}')

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo -e "${RED}Insufficient disk space!${NC}"
    echo "Required: ${REQUIRED_SPACE}GB"
    echo "Available: ${AVAILABLE_SPACE}GB"
    exit 1
fi

echo -e "${GREEN}Disk space check:${NC} OK (${AVAILABLE_SPACE}GB available)"
echo ""

# Download IPSW
echo -e "${BLUE}Downloading IPSW...${NC}"
echo "URL: $IPSW_URL"
echo "Destination: $IPSW_FILE"
echo ""
echo "This will take 10-30 minutes depending on your connection..."
echo ""

# Use curl with progress bar
if ! curl -# -L -o "$IPSW_FILE" "$IPSW_URL"; then
    echo -e "${RED}Download failed!${NC}"
    echo ""
    echo "Possible reasons:"
    echo "1. Network connection issue"
    echo "2. Apple changed the URL"
    echo "3. Disk space ran out"
    echo ""
    echo "Try manual download from: https://ipsw.me"
    rm -f "$IPSW_FILE"
    exit 1
fi

echo ""
echo -e "${GREEN}Download complete!${NC}"
echo ""

# Verify file
if [ ! -f "$IPSW_FILE" ]; then
    echo -e "${RED}IPSW file not found after download!${NC}"
    exit 1
fi

FILE_SIZE=$(du -h "$IPSW_FILE" | cut -f1)
echo -e "${GREEN}File size:${NC} $FILE_SIZE"
echo ""

# Basic validation (IPSW files should be > 10GB)
FILE_SIZE_BYTES=$(stat -f%z "$IPSW_FILE" 2>/dev/null || stat -c%s "$IPSW_FILE")
MIN_SIZE=$((10 * 1024 * 1024 * 1024))  # 10GB in bytes

if [ "$FILE_SIZE_BYTES" -lt "$MIN_SIZE" ]; then
    echo -e "${RED}Warning: File seems too small!${NC}"
    echo "Expected: >10GB"
    echo "Got: $FILE_SIZE"
    echo ""
    echo "The download may have failed. Try again."
    exit 1
fi

echo -e "${GREEN}✓ IPSW downloaded successfully!${NC}"
echo ""
echo "Location: $IPSW_FILE"
echo "Size: $FILE_SIZE"
echo ""
echo -e "${BLUE}Next step:${NC} ./scripts/create-macos-vm.sh"
echo ""
