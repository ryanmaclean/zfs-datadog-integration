#!/bin/bash
#
# Install code-server on Raspberry Pi (ARM64)
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  code-server for Raspberry Pi (ARM64)                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo -e "${YELLOW}Warning: Not ARM64 architecture (detected: $ARCH)${NC}"
    echo "This script is for ARM64. Continue anyway? (y/N)"
    read -r -n 1 CONTINUE
    echo ""
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Architecture: $ARCH${NC}"
echo ""

# Update system
echo -e "${BLUE}[1/5] Updating system...${NC}"
sudo apt update
sudo apt upgrade -y
echo -e "${GREEN}✓ System updated${NC}"
echo ""

# Install Node.js
echo -e "${BLUE}[2/5] Installing Node.js...${NC}"
if command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js already installed: $(node --version)${NC}"
else
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    echo -e "${GREEN}✓ Node.js installed${NC}"
fi

NODE_VERSION=$(node --version)
echo "Node.js: $NODE_VERSION ($(node -p 'process.arch'))"
echo ""

# Install code-server
echo -e "${BLUE}[3/5] Installing code-server...${NC}"
if command -v code-server &> /dev/null; then
    echo -e "${YELLOW}code-server already installed${NC}"
else
    curl -fsSL https://code-server.dev/install.sh | sh
    echo -e "${GREEN}✓ code-server installed${NC}"
fi

CS_VERSION=$(code-server --version | head -1)
echo "code-server: $CS_VERSION"
echo ""

# Configure
echo -e "${BLUE}[4/5] Configuring code-server...${NC}"
mkdir -p ~/.config/code-server

PASSWORD=$(openssl rand -base64 32)

cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $PASSWORD
cert: false
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

# Install ML extension
echo -e "${BLUE}[5/5] Installing ML Code Assistant...${NC}"
EXTENSIONS_DIR="$HOME/.local/share/code-server/extensions"
mkdir -p "$EXTENSIONS_DIR"

if [ -d "./code-app-ml-extension" ]; then
    cp -r ./code-app-ml-extension "$EXTENSIONS_DIR/mlcode-extension"
    cd "$EXTENSIONS_DIR/mlcode-extension"
    npm install
    cd -
    echo -e "${GREEN}✓ ML extension installed${NC}"
else
    echo -e "${YELLOW}ML extension not found (optional)${NC}"
fi
echo ""

# Enable systemd service
echo "Enable code-server to start on boot? (Y/n)"
read -r -n 1 ENABLE_SERVICE
echo ""

if [[ ! $ENABLE_SERVICE =~ ^[Nn]$ ]]; then
    sudo systemctl enable --now code-server@$USER
    echo -e "${GREEN}✓ Service enabled${NC}"
else
    echo -e "${YELLOW}Service not enabled. Start manually: code-server${NC}"
fi
echo ""

# Get IP address
IP=$(hostname -I | awk '{print $1}')

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Installation Complete!                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Access code-server:"
echo "  Local:  http://localhost:8080"
echo "  Network: http://$IP:8080"
echo ""
echo -e "${YELLOW}Password: $PASSWORD${NC}"
echo ""
echo "Save this password!"
echo ""
echo "Raspberry Pi Info:"
echo "  Model: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
echo "  CPU: $(nproc) cores"
echo "  RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "  Arch: $ARCH"
echo ""
echo "To start manually: code-server"
echo "To check status: sudo systemctl status code-server@$USER"
echo ""
echo -e "${GREEN}Ready to code on Raspberry Pi! 🚀${NC}"
echo ""
