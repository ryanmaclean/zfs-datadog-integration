#!/bin/bash
#
# Create macOS VM using Lima and IPSW
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  macOS VM Creator                                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Lima is installed
if ! command -v limactl &> /dev/null; then
    echo -e "${RED}Lima is not installed!${NC}"
    echo ""
    echo "Install with: brew install lima"
    exit 1
fi

echo -e "${GREEN}✓ Lima is installed${NC}"
echo ""

# Find IPSW file
IPSW_DIR="$(dirname "$0")/../ipsw"
IPSW_FILE=$(find "$IPSW_DIR" -name "*.ipsw" -type f | head -1)

if [ -z "$IPSW_FILE" ]; then
    echo -e "${RED}No IPSW file found!${NC}"
    echo ""
    echo "Run: ./scripts/download-ipsw.sh"
    exit 1
fi

echo -e "${GREEN}Found IPSW:${NC} $IPSW_FILE"
echo ""

# VM configuration
VM_NAME="macos-dev"
VM_CPUS=4
VM_MEMORY="8GiB"
VM_DISK="50GiB"

echo "VM Configuration:"
echo "  Name: $VM_NAME"
echo "  CPUs: $VM_CPUS"
echo "  Memory: $VM_MEMORY"
echo "  Disk: $VM_DISK"
echo "  IPSW: $(basename "$IPSW_FILE")"
echo ""

# Check if VM already exists
if limactl list | grep -q "$VM_NAME"; then
    echo -e "${YELLOW}VM '$VM_NAME' already exists!${NC}"
    echo ""
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing VM..."
        limactl delete -f "$VM_NAME"
    else
        echo "Keeping existing VM"
        exit 0
    fi
fi

# Create Lima config
CONFIG_FILE="/tmp/macos-dev.yaml"

cat > "$CONFIG_FILE" <<EOF
# macOS VM for development with code-server
vmType: "vz"
os: null
arch: "aarch64"

images:
  - location: "file://$(realpath "$IPSW_FILE")"
    arch: "aarch64"

cpus: $VM_CPUS
memory: "$VM_MEMORY"
disk: "$VM_DISK"

firmware:
  legacyBIOS: false

video:
  display: "none"

network:
  - vzNAT: true

mounts:
  - location: "~"
    writable: false
  - location: "/tmp/lima"
    writable: true

provision:
  - mode: system
    script: |
      #!/bin/bash
      set -eux -o pipefail
      echo "macOS VM provisioning..."
      
  - mode: user
    script: |
      #!/bin/bash
      set -eux -o pipefail
      echo "User provisioning complete"

EOF

echo -e "${BLUE}Creating macOS VM...${NC}"
echo ""
echo "This will:"
echo "1. Create VM from IPSW"
echo "2. Boot macOS installer"
echo "3. Wait for installation (15-20 min)"
echo ""

# Create and start VM
if ! limactl create --name="$VM_NAME" "$CONFIG_FILE"; then
    echo -e "${RED}VM creation failed!${NC}"
    echo ""
    echo "Check logs: limactl shell $VM_NAME -- dmesg"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ VM created successfully!${NC}"
echo ""

# Start VM
echo -e "${BLUE}Starting VM...${NC}"
echo ""

if ! limactl start "$VM_NAME"; then
    echo -e "${RED}VM start failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ VM started!${NC}"
echo ""

# Wait for VM to be ready
echo "Waiting for macOS to boot..."
sleep 10

# Check VM status
echo ""
echo "VM Status:"
limactl list | grep "$VM_NAME"
echo ""

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  macOS Installation Started                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "The macOS installer is now running inside the VM."
echo ""
echo "Installation steps:"
echo "1. macOS installer will start automatically"
echo "2. Follow on-screen prompts (if using VNC)"
echo "3. Create user account"
echo "4. Wait for installation (15-20 minutes)"
echo "5. VM will reboot when complete"
echo ""
echo "To check progress:"
echo "  limactl shell $VM_NAME"
echo ""
echo "To stop VM:"
echo "  limactl stop $VM_NAME"
echo ""
echo -e "${BLUE}Next step (after installation):${NC} ./scripts/install-code-server.sh"
echo ""
