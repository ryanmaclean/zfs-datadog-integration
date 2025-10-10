#!/bin/bash
#
# QEMU-based OpenBSD Testing
# Downloads and runs OpenBSD 7.6 with ZFS support
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_URL="https://github.com/hcartiaux/openbsd-cloud-image/releases/download/v7.6_2024-10-03-20-41/openbsd-generic.qcow2"
IMAGE_FILE="${SCRIPT_DIR}/openbsd-7.6.qcow2"

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

log_info "Using x86_64 architecture (OpenBSD cloud image)"

# Download image if not present
if [ ! -f "$IMAGE_FILE" ]; then
    log_info "Downloading OpenBSD 7.6 cloud image..."
    log_info "URL: $IMAGE_URL"
    curl -L -o "$IMAGE_FILE" "$IMAGE_URL"
    log_success "Image downloaded"
else
    log_info "Image already exists: $IMAGE_FILE"
fi

# Resize disk
log_info "Resizing disk to 20G..."
qemu-img resize "$IMAGE_FILE" 20G

# Start VM
log_info "Starting OpenBSD VM..."
log_warning "Note: OpenBSD does not have native ZFS support"
log_info "OpenBSD uses OpenZFS via ports (experimental)"
log_info "SSH will be available on port 2225"
echo ""
echo "After boot:"
echo "1. SSH: ssh -p 2225 root@localhost"
echo "2. Install OpenZFS: pkg_add openzfs"
echo "3. Load kernel module: kldload zfs"
echo "4. Copy zedlets: scp -P 2225 *.sh root@localhost:/tmp/"
echo ""

# Run QEMU
qemu-system-x86_64 \
    -accel hvf \
    -machine q35 \
    -cpu host \
    -smp 2 \
    -m 4G \
    -drive file="$IMAGE_FILE",if=virtio,format=qcow2 \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2225-:22 \
    -display default \
    -name "OpenBSD 7.6"

log_info "VM stopped"
