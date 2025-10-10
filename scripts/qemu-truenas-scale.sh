#!/bin/bash
#
# QEMU-based TrueNAS SCALE Testing
# Downloads and runs TrueNAS SCALE in QEMU for zedlet testing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="truenas-scale"
ISO_URL="https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/TrueNAS-SCALE-24.04.2.2.iso"
ISO_FILE="${SCRIPT_DIR}/truenas-scale.iso"
DISK_IMG="${SCRIPT_DIR}/truenas-scale-disk.qcow2"
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
if ! command -v qemu-system-aarch64 &> /dev/null && ! command -v qemu-system-x86_64 &> /dev/null; then
    log_error "QEMU not found. Installing via Homebrew..."
    brew install qemu
fi

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    QEMU_CMD="qemu-system-aarch64"
    QEMU_MACHINE="virt,highmem=on"
    QEMU_CPU="host"
    QEMU_ACCEL="-accel hvf"  # macOS Hypervisor.framework
    log_info "Using ARM64 architecture"
else
    QEMU_CMD="qemu-system-x86_64"
    QEMU_MACHINE="q35"
    QEMU_CPU="host"
    QEMU_ACCEL="-accel hvf"
    log_info "Using x86_64 architecture"
fi

# Download ISO if not present
if [ ! -f "$ISO_FILE" ]; then
    log_info "Downloading TrueNAS SCALE ISO (1.4GB)..."
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
log_info "Starting TrueNAS SCALE VM..."
log_warning "This will open a QEMU window"
log_info "Install TrueNAS SCALE, then you can SSH in to test zedlets"
echo ""
echo "After installation:"
echo "1. Configure network in TrueNAS web UI (http://truenas-ip)"
echo "2. Enable SSH in System Settings"
echo "3. Copy zedlets: scp *.sh root@truenas-ip:/tmp/"
echo "4. Install zedlets: ssh root@truenas-ip 'bash /tmp/install.sh'"
echo ""

# Run QEMU
$QEMU_CMD \
    $QEMU_ACCEL \
    -machine $QEMU_MACHINE \
    -cpu $QEMU_CPU \
    -smp 2 \
    -m 8G \
    -cdrom "$ISO_FILE" \
    -drive file="$DISK_IMG",if=virtio,format=qcow2 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::8443-:443 \
    -display default \
    -name "TrueNAS SCALE"

log_info "VM stopped"
