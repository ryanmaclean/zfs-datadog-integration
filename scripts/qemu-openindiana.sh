#!/bin/bash
#
# QEMU-based OpenIndiana Testing
# Downloads and runs OpenIndiana Hipster with native ZFS
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_URL="https://dlc.openindiana.org/isos/hipster/20231030/OI-hipster-text-20231030.iso"
ISO_FILE="${SCRIPT_DIR}/openindiana-hipster.iso"
DISK_IMG="${SCRIPT_DIR}/openindiana-disk.qcow2"
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

log_info "Using x86_64 architecture (OpenIndiana is x64 only)"

# Download ISO if not present
if [ ! -f "$ISO_FILE" ]; then
    log_info "Downloading OpenIndiana Hipster ISO (~700MB)..."
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
log_info "Starting OpenIndiana VM..."
log_warning "OpenIndiana has NATIVE ZFS support (Illumos-based)"
log_info "SSH will be available on port 2227"
echo ""
echo "After installation:"
echo "1. Install OpenIndiana (text installer)"
echo "2. Configure network"
echo "3. Enable SSH: svcadm enable ssh"
echo "4. SSH: ssh -p 2227 root@localhost"
echo "5. Copy zedlets: scp -P 2227 *.sh root@localhost:/tmp/"
echo "6. ZFS is already installed (native)"
echo ""
echo "Note: OpenIndiana uses /etc/zfs/zed.d/ for zedlets"
echo "      Service management: svcadm restart zfs-zed"
echo ""

# Run QEMU
qemu-system-x86_64 \
    -accel hvf \
    -machine q35 \
    -cpu host \
    -smp 2 \
    -m 4G \
    -cdrom "$ISO_FILE" \
    -drive file="$DISK_IMG",if=virtio,format=qcow2 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2227-:22 \
    -display default \
    -name "OpenIndiana Hipster"

log_info "VM stopped"
