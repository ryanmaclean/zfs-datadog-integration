#!/bin/bash
#
# QEMU-based FreeBSD Testing
# Downloads and runs FreeBSD 14.2 in QEMU for zedlet testing
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="freebsd"

# Determine architecture
# Use x86_64 for better compatibility (works on both ARM64 and x86_64)
IMAGE_URL="https://download.freebsd.org/releases/VM-IMAGES/14.3-RELEASE/amd64/Latest/FreeBSD-14.3-RELEASE-amd64-BASIC-CLOUDINIT.qcow2.xz"
IMAGE_FILE="${SCRIPT_DIR}/freebsd-amd64.qcow2.xz"
QCOW_FILE="${SCRIPT_DIR}/freebsd-amd64.qcow2"
QEMU_CMD="qemu-system-x86_64"
QEMU_MACHINE="q35"
QEMU_CPU="max"  # Use 'max' for emulation compatibility
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
        log_info "Downloading FreeBSD cloud image..."
        log_info "URL: $IMAGE_URL"
        curl -L -o "$IMAGE_FILE" "$IMAGE_URL"
        log_success "Image downloaded"
    fi
    
    log_info "Extracting image..."
    xz -d -k "$IMAGE_FILE"
    log_success "Image extracted"
else
    log_info "Image already exists: $QCOW_FILE"
fi

# Resize disk
log_info "Resizing disk to 20G..."
qemu-img resize "$QCOW_FILE" 20G

# Create cloud-init config
CLOUD_INIT_DIR="${SCRIPT_DIR}/cloud-init-freebsd"
mkdir -p "$CLOUD_INIT_DIR"

cat > "$CLOUD_INIT_DIR/meta-data" <<EOF
instance-id: freebsd-test
local-hostname: freebsd-test
EOF

cat > "$CLOUD_INIT_DIR/user-data" <<'EOF'
#cloud-config
users:
  - name: freebsd
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/sh
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... # Add your SSH key here

chpasswd:
  list: |
    freebsd:freebsd
    root:freebsd
  expire: false

package_update: true
packages:
  - curl

runcmd:
  - echo "FreeBSD cloud-init setup complete"
EOF

# Create cloud-init ISO
CLOUD_INIT_ISO="${SCRIPT_DIR}/cloud-init-freebsd.iso"
if command -v mkisofs &> /dev/null; then
    mkisofs -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock "$CLOUD_INIT_DIR"
elif command -v genisoimage &> /dev/null; then
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock "$CLOUD_INIT_DIR"
else
    log_warning "mkisofs/genisoimage not found, cloud-init may not work"
    log_info "Install with: brew install cdrtools"
fi

# Start VM
log_info "Starting FreeBSD VM..."
log_warning "Default login: freebsd/freebsd or root/freebsd"
log_info "SSH will be available on port 2224"
echo ""
echo "After boot:"
echo "1. SSH: ssh -p 2224 freebsd@localhost"
echo "2. Copy zedlets: scp -P 2224 *.sh freebsd@localhost:/tmp/"
echo "3. Install: ssh -p 2224 freebsd@localhost 'sudo bash /tmp/install.sh'"
echo ""
echo "Note: FreeBSD uses /usr/local/etc/zfs/zed.d/ for zedlets"
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
    -cdrom "$CLOUD_INIT_ISO" \
    -net nic,model=virtio \
    -net user,hostfwd=tcp::2224-:22 \
    -display default \
    -name "FreeBSD 14.2"

log_info "VM stopped"
