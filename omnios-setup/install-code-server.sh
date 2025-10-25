#!/bin/bash
#
# Install code-server on OmniOS/Solaris (illumos)
# Tested on: OmniOS r151048+
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  code-server Installation for OmniOS/Solaris          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check OS
OS=$(uname -s)
if [ "$OS" != "SunOS" ]; then
    echo -e "${YELLOW}Warning: This script is for OmniOS/Solaris (detected: $OS)${NC}"
    echo "Continuing anyway..."
fi

echo -e "${GREEN}Detected OS:${NC} $OS"
echo -e "${GREEN}Kernel:${NC} $(uname -r)"
echo -e "${GREEN}Architecture:${NC} $(uname -p)"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Running as root - good for system-wide install${NC}"
    SUDO=""
else
    echo -e "${YELLOW}Running as user - will use sudo for system operations${NC}"
    SUDO="sudo"
fi
echo ""

# Install Node.js
echo -e "${BLUE}Step 1: Installing Node.js${NC}"
echo ""

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js already installed: $NODE_VERSION${NC}"
else
    echo "Installing Node.js via pkg..."
    $SUDO pkg install nodejs || {
        echo -e "${RED}Failed to install Node.js via pkg${NC}"
        echo ""
        echo "Alternative: Install manually"
        echo "1. Download from: https://nodejs.org/dist/"
        echo "2. Extract and add to PATH"
        exit 1
    }
    echo -e "${GREEN}✓ Node.js installed${NC}"
fi

NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo ""
echo "Node.js: $NODE_VERSION"
echo "npm: $NPM_VERSION"
echo ""

# Install code-server
echo -e "${BLUE}Step 2: Installing code-server${NC}"
echo ""

if command -v code-server &> /dev/null; then
    CS_VERSION=$(code-server --version | head -1)
    echo -e "${GREEN}✓ code-server already installed: $CS_VERSION${NC}"
else
    echo "Installing code-server via npm..."
    npm install -g code-server || {
        echo -e "${RED}Failed to install code-server via npm${NC}"
        echo ""
        echo "Alternative: Manual installation"
        echo "1. Download from: https://github.com/coder/code-server/releases"
        echo "2. Extract and run"
        exit 1
    }
    echo -e "${GREEN}✓ code-server installed${NC}"
fi

CS_VERSION=$(code-server --version | head -1)
echo ""
echo "code-server: $CS_VERSION"
echo ""

# Create config directory
echo -e "${BLUE}Step 3: Creating configuration${NC}"
echo ""

CONFIG_DIR="$HOME/.config/code-server"
mkdir -p "$CONFIG_DIR"

# Generate random password
PASSWORD=$(openssl rand -base64 32 2>/dev/null || dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)

# Create config
cat > "$CONFIG_DIR/config.yaml" <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $PASSWORD
cert: false
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""
echo "Config location: $CONFIG_DIR/config.yaml"
echo ""
echo -e "${YELLOW}IMPORTANT: Save this password!${NC}"
echo -e "${GREEN}Password: $PASSWORD${NC}"
echo ""

# Install ML Code Assistant extension
echo -e "${BLUE}Step 4: Installing ML Code Assistant${NC}"
echo ""

EXTENSIONS_DIR="$HOME/.local/share/code-server/extensions"
mkdir -p "$EXTENSIONS_DIR"

# Check if extension directory exists
if [ -d "./code-app-ml-extension" ]; then
    echo "Copying ML Code Assistant extension..."
    cp -r ./code-app-ml-extension "$EXTENSIONS_DIR/mlcode-extension"
    
    echo "Installing extension dependencies..."
    cd "$EXTENSIONS_DIR/mlcode-extension"
    npm install
    cd -
    
    echo -e "${GREEN}✓ ML Code Assistant installed${NC}"
else
    echo -e "${YELLOW}ML Code Assistant not found in current directory${NC}"
    echo "To install later:"
    echo "  1. Copy code-app-ml-extension to $EXTENSIONS_DIR/mlcode-extension"
    echo "  2. Run: cd $EXTENSIONS_DIR/mlcode-extension && npm install"
fi
echo ""

# Create SMF service (OmniOS-specific)
echo -e "${BLUE}Step 5: Creating SMF service (optional)${NC}"
echo ""

if command -v svccfg &> /dev/null; then
    echo "Creating SMF service manifest..."
    
    SERVICE_NAME="code-server"
    MANIFEST="/var/svc/manifest/application/${SERVICE_NAME}.xml"
    
    cat > /tmp/${SERVICE_NAME}.xml <<EOF
<?xml version="1.0"?>
<!DOCTYPE service_bundle SYSTEM "/usr/share/lib/xml/dtd/service_bundle.dtd.1">
<service_bundle type='manifest' name='${SERVICE_NAME}'>
  <service name='application/${SERVICE_NAME}' type='service' version='1'>
    <create_default_instance enabled='false' />
    <single_instance />
    
    <dependency name='network' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/milestone/network:default' />
    </dependency>
    
    <dependency name='filesystem' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/system/filesystem/local' />
    </dependency>
    
    <exec_method type='method' name='start' exec='/usr/bin/code-server' timeout_seconds='60'>
      <method_context>
        <method_credential user='$USER' />
      </method_context>
    </exec_method>
    
    <exec_method type='method' name='stop' exec=':kill' timeout_seconds='60' />
    
    <property_group name='startd' type='framework'>
      <propval name='duration' type='astring' value='child' />
      <propval name='ignore_error' type='astring' value='core,signal' />
    </property_group>
    
    <stability value='Evolving' />
    
    <template>
      <common_name>
        <loctext xml:lang='C'>code-server</loctext>
      </common_name>
    </template>
  </service>
</service_bundle>
EOF
    
    echo "To enable SMF service:"
    echo "  $SUDO cp /tmp/${SERVICE_NAME}.xml $MANIFEST"
    echo "  $SUDO svccfg import $MANIFEST"
    echo "  $SUDO svcadm enable ${SERVICE_NAME}"
else
    echo "SMF not available (not on OmniOS?)"
    echo "To start manually: code-server"
fi
echo ""

# Get IP address
echo -e "${BLUE}Step 6: Network Information${NC}"
echo ""

IP=$(ifconfig -a | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
echo "Server IP: $IP"
echo ""

# Final instructions
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Installation Complete!                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "To start code-server:"
echo "  code-server"
echo ""
echo "Access from browser:"
echo "  http://$IP:8080"
echo "  http://localhost:8080 (on this machine)"
echo ""
echo -e "${YELLOW}Password: $PASSWORD${NC}"
echo ""
echo "To start on boot (OmniOS):"
echo "  $SUDO cp /tmp/${SERVICE_NAME}.xml /var/svc/manifest/application/"
echo "  $SUDO svccfg import /var/svc/manifest/application/${SERVICE_NAME}.xml"
echo "  $SUDO svcadm enable ${SERVICE_NAME}"
echo ""
echo "Logs:"
echo "  ~/.local/share/code-server/code-server.log"
echo ""
echo -e "${GREEN}Ready to code on OmniOS! 🚀${NC}"
echo ""
