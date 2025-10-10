#!/bin/bash
#
# QEMU-based TrueNAS CORE Testing
# Downloads and runs TrueNAS CORE (FreeBSD-based) in QEMU for zedlet testing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="truenas-core"
ISO_URL="https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/TrueNAS-13.3-RELEASE.iso"
ISO_FILE="${SCRIPT_DIR}/truenas-core.iso"
DISK_IMG="${SCRIPT_DIR}/truenas-core-disk.qcow2"
DISK_SIZE="20G"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check if QEMU is installed
if ! command -v qemu-system-x86_64 &> /dev/null; then
    log_error "QEMU not found. Installing via Homebrew..."
    brew install qemu
fi

log_info "Using x86_64 architecture (TrueNAS CORE is x64 only)"

# Download ISO if not present
if [ ! -f "$ISO_FILE" ]; then
    log_info "Downloading TrueNAS CORE ISO (~700MB)..."
    log_info "URL: $ISO_URL"
    curl -L -o "$ISO_FILE" "$ISO_URL"
    log_success "ISO downloaded"
else
    log_info "ISO already exists: $ISO_FILE"
fi

# Create disk image if not present
if [ ! -f "$DISK_IMG" ]; then
    log_info "Creating virtual disk ($DISK_SIZE)..."
    qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
    log_success "Disk created"
else
    log_info "Disk already exists: $DISK_IMG"
fi

# Start VM
log_info "Starting TrueNAS CORE VM..."
log_warning "This will open a QEMU window"
log_info "Install TrueNAS CORE, then you can SSH in to test zedlets"
echo ""
echo "After installation:"
echo "1. Configure network in TrueNAS web UI (http://truenas-ip)"
echo "2. Enable SSH in System Settings"
echo "3. Copy zedlets: scp *.sh root@truenas-ip:/tmp/"
echo "4. Install manually (TrueNAS CORE uses /usr/local/etc/zfs/zed.d/)"
echo ""

# Run QEMU (x86_64 emulation on ARM64 will be slow)
qemu-system-x86_64 \
    -accel hvf \
    -machine q35 \
    -cpu host \
    -smp 2 \
    -m 8G \
    -cdrom "$ISO_FILE" \
    -drive file="$DISK_IMG",if=virtio,format=qcow2 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2223-:22,hostfwd=tcp::8444-:443 \
    -display default \
    -name "TrueNAS CORE"

log_info "VM stopped"
