#!/bin/bash
#
# Install code-server in macOS VM
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  code-server Installer                                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

VM_NAME="macos-dev"

# Check if VM exists and is running
if ! limactl list | grep "$VM_NAME" | grep -q "Running"; then
    echo -e "${RED}VM '$VM_NAME' is not running!${NC}"
    echo ""
    echo "Start with: limactl start $VM_NAME"
    exit 1
fi

echo -e "${GREEN}✓ VM is running${NC}"
echo ""

# Install code-server
echo -e "${BLUE}Installing code-server in VM...${NC}"
echo ""

limactl shell "$VM_NAME" <<'INSTALL_SCRIPT'
#!/bin/bash
set -e

echo "Installing code-server..."

# Install code-server
curl -fsSL https://code-server.dev/install.sh | sh

echo ""
echo "✓ code-server installed"
echo ""

# Create config directory
mkdir -p ~/.config/code-server

# Generate random password
PASSWORD=$(openssl rand -base64 32)

# Create config
cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $PASSWORD
cert: false
EOF

echo "✓ Configuration created"
echo ""
echo "Password: $PASSWORD"
echo ""
echo "IMPORTANT: Save this password!"
echo ""

# Create systemd service (if systemd available)
if command -v systemctl &> /dev/null; then
    sudo tee /etc/systemd/system/code-server.service > /dev/null <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=$USER
Environment=PASSWORD=$PASSWORD
ExecStart=/usr/bin/code-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable code-server
    sudo systemctl start code-server
    
    echo "✓ code-server service started"
else
    # Start manually
    nohup code-server > ~/.config/code-server/code-server.log 2>&1 &
    echo "✓ code-server started (manual)"
fi

echo ""
echo "code-server is now running on port 8080"
echo ""

INSTALL_SCRIPT

echo ""
echo -e "${GREEN}✓ code-server installed successfully!${NC}"
echo ""

# Get VM IP
VM_IP=$(limactl shell "$VM_NAME" -- hostname -I | awk '{print $1}')

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Installation Complete!                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Access code-server:"
echo ""
echo "  From host Mac:"
echo "    http://$VM_IP:8080"
echo ""
echo "  Or use port forwarding:"
echo "    ssh -L 8080:localhost:8080 lima-$VM_NAME"
echo "    http://localhost:8080"
echo ""
echo "  Or open directly:"
echo "    open http://$VM_IP:8080"
echo ""
echo "Password is shown above (save it!)"
echo ""
echo "To view password again:"
echo "  limactl shell $VM_NAME -- cat ~/.config/code-server/config.yaml"
echo ""
