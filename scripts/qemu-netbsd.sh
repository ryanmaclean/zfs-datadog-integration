#!/bin/bash
#
# QEMU-based NetBSD Testing
# Downloads and runs NetBSD 10.0 with ZFS support
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use x86_64 for better compatibility
IMAGE_URL="https://cdn.netbsd.org/pub/NetBSD/images/10.0/NetBSD-10.0-amd64.img.gz"
IMAGE_FILE="${SCRIPT_DIR}/netbsd-10.0-amd64.img.gz"
QCOW_FILE="${SCRIPT_DIR}/netbsd-10.0-amd64.qcow2"
QEMU_CMD="qemu-system-x86_64"
QEMU_MACHINE="q35"
QEMU_CPU="max"  # Use 'max' for emulation
QEMU_BIOS=""

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
if ! command -v $QEMU_CMD &> /dev/null; then
    log_error "QEMU not found. Installing via Homebrew..."
    brew install qemu
fi

log_info "Using $ARCH architecture"

# Download image if not present
if [ ! -f "$QCOW_FILE" ]; then
    if [ ! -f "$IMAGE_FILE" ]; then
        log_info "Downloading NetBSD 10.0 image..."
        log_info "URL: $IMAGE_URL"
        curl -L -o "$IMAGE_FILE" "$IMAGE_URL"
        log_success "Image downloaded"
    fi
    
    log_info "Extracting and converting image..."
    gunzip -c "$IMAGE_FILE" > "${QCOW_FILE%.qcow2}.img"
    qemu-img convert -f raw -O qcow2 "${QCOW_FILE%.qcow2}.img" "$QCOW_FILE"
    rm "${QCOW_FILE%.qcow2}.img"
    log_success "Image converted"
else
    log_info "Image already exists: $QCOW_FILE"
fi

# Resize disk
log_info "Resizing disk to 20G..."
qemu-img resize "$QCOW_FILE" 20G

# Start VM
log_info "Starting NetBSD VM..."
log_warning "NetBSD has ZFS support via pkgsrc"
log_info "SSH will be available on port 2226"
echo ""
echo "After boot:"
echo "1. Login as root (no password initially)"
echo "2. Set password: passwd"
echo "3. Install ZFS: pkgin install zfs"
echo "4. Load kernel module: modload zfs"
echo "5. SSH: ssh -p 2226 root@localhost"
echo "6. Copy zedlets: scp -P 2226 *.sh root@localhost:/tmp/"
echo ""

# Run QEMU
$QEMU_CMD \
    -accel hvf \
    -machine $QEMU_MACHINE \
    -cpu $QEMU_CPU \
    $QEMU_BIOS \
    -smp 2 \
    -m 4G \
    -drive file="$QCOW_FILE",if=virtio,format=qcow2 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2226-:22 \
    -display default \
    -name "NetBSD 10.0"

log_info "VM stopped"
