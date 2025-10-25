#!/bin/bash
#
# Easy macOS VM setup with Tart (for certified developers)
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Tart macOS VM Setup (for Certified Developers)       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Tart is installed
if ! command -v tart &> /dev/null; then
    echo -e "${YELLOW}Tart not installed. Installing...${NC}"
    brew install cirruslabs/cli/tart
    echo -e "${GREEN}✓ Tart installed${NC}"
else
    echo -e "${GREEN}✓ Tart is already installed${NC}"
    tart --version
fi
echo ""

# Choose macOS version
echo "Which macOS version do you want?"
echo "1) Ventura (13) - Base"
echo "2) Ventura (13) - With Xcode"
echo "3) Sonoma (14) - Base"
echo "4) Sonoma (14) - With Xcode"
echo ""
read -p "Choice (1-4): " choice

case $choice in
    1)
        IMAGE="ghcr.io/cirruslabs/macos-ventura-base:latest"
        VM_NAME="ventura"
        ;;
    2)
        IMAGE="ghcr.io/cirruslabs/macos-ventura-xcode:latest"
        VM_NAME="ventura-xcode"
        ;;
    3)
        IMAGE="ghcr.io/cirruslabs/macos-sonoma-base:latest"
        VM_NAME="sonoma"
        ;;
    4)
        IMAGE="ghcr.io/cirruslabs/macos-sonoma-xcode:latest"
        VM_NAME="sonoma-xcode"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}Pulling image: $IMAGE${NC}"
echo "This will take 5-15 minutes (25-40GB download)"
echo ""

# Pull image
if ! tart clone "$IMAGE" "$VM_NAME"; then
    echo -e "${RED}Failed to pull image${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Image pulled successfully${NC}"
echo ""

# Ask about code-server
read -p "Install code-server in VM? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Starting VM...${NC}"
    
    # Start VM in background
    tart run --no-graphics "$VM_NAME" &
    VM_PID=$!
    
    echo "Waiting for VM to boot (30 seconds)..."
    sleep 30
    
    # Get VM IP
    VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || echo "")
    
    if [ -z "$VM_IP" ]; then
        echo -e "${YELLOW}Could not get VM IP. VM may still be booting.${NC}"
        echo "Wait a minute and run: tart ip $VM_NAME"
    else
        echo -e "${GREEN}VM IP: $VM_IP${NC}"
        
        # Install code-server
        echo ""
        echo -e "${BLUE}Installing code-server in VM...${NC}"
        
        # Note: This requires SSH access to be set up in the VM
        # For now, provide manual instructions
        echo ""
        echo -e "${YELLOW}Manual steps (run inside the VM):${NC}"
        echo ""
        echo "1. Stop the VM (Cmd+Q)"
        echo "2. Start with GUI: tart run $VM_NAME"
        echo "3. Inside VM, open Terminal and run:"
        echo ""
        echo "   curl -fsSL https://code-server.dev/install.sh | sh"
        echo "   mkdir -p ~/.config/code-server"
        echo "   cat > ~/.config/code-server/config.yaml <<EOF"
        echo "bind-addr: 0.0.0.0:8080"
        echo "auth: password"
        echo "password: tart-dev-2025"
        echo "cert: false"
        echo "EOF"
        echo "   code-server &"
        echo ""
        echo "4. Access from host: http://$VM_IP:8080"
        echo "   Password: tart-dev-2025"
        echo ""
    fi
else
    echo ""
    echo -e "${GREEN}VM ready!${NC}"
    echo ""
    echo "Start with: tart run $VM_NAME"
    echo "Start headless: tart run --no-graphics $VM_NAME"
    echo "Get IP: tart ip $VM_NAME"
    echo ""
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Setup Complete!                                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "VM Name: $VM_NAME"
echo "Image: $IMAGE"
echo ""
echo "Commands:"
echo "  Start: tart run $VM_NAME"
echo "  Start headless: tart run --no-graphics $VM_NAME"
echo "  Get IP: tart ip $VM_NAME"
echo "  Stop: Cmd+Q (or kill process)"
echo "  Delete: tart delete $VM_NAME"
echo ""
