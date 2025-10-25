#!/bin/bash
#
# Universal Esoteric OS Booter
# Boots unusual operating systems in Lima + QEMU with code-server access
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

OS_NAME=$1
ISO_URL=$2
MEMORY=${3:-2048}
CPUS=${4:-2}
VNC_PORT=${5:-1}

show_usage() {
    echo "Usage: $0 <os-name> <iso-url> [memory-mb] [cpus] [vnc-port]"
    echo ""
    echo "Examples:"
    echo "  $0 plan9 http://9legacy.org/download/go/9legacy.iso.bz2"
    echo "  $0 redox https://static.redox-os.org/releases/0.8.0/x86_64/redox_demo_x86_64_0.8.0.iso 4096 4"
    echo "  $0 minix http://download.minix3.org/iso/minix_R3.4.0-588a35b.iso.bz2 1024 2"
    echo ""
    echo "Pre-configured OSes:"
    echo "  $0 plan9"
    echo "  $0 redox"
    echo "  $0 minix"
    echo "  $0 haiku"
    echo "  $0 templeos"
    echo "  $0 serenity"
}

# Pre-configured OSes
case "$OS_NAME" in
    plan9)
        ISO_URL="http://9legacy.org/download/go/9legacy.iso.bz2"
        MEMORY=1024
        CPUS=2
        ;;
    redox)
        ISO_URL="https://static.redox-os.org/releases/0.8.0/x86_64/redox_demo_x86_64_0.8.0.iso"
        MEMORY=2048
        CPUS=2
        ;;
    minix)
        ISO_URL="http://download.minix3.org/iso/minix_R3.4.0-588a35b.iso.bz2"
        MEMORY=1024
        CPUS=2
        ;;
    haiku)
        ISO_URL="https://cdn.haiku-os.org/haiku-release/r1beta4/haiku-r1beta4-x86_64-anyboot.iso"
        MEMORY=2048
        CPUS=2
        ;;
    templeos)
        ISO_URL="https://templeos.org/Downloads/TempleOS.ISO"
        MEMORY=512
        CPUS=1
        ;;
    serenity)
        echo -e "${YELLOW}SerenityOS requires building from source (1-2 hours)${NC}"
        echo "Use: ./boot-serenity.sh instead"
        exit 1
        ;;
    "")
        show_usage
        exit 1
        ;;
esac

if [ -z "$ISO_URL" ]; then
    echo -e "${RED}Error: ISO URL required${NC}"
    show_usage
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Esoteric OS Booter: ${OS_NAME}${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuration:"
echo "  OS: $OS_NAME"
echo "  ISO: $ISO_URL"
echo "  Memory: ${MEMORY}MB"
echo "  CPUs: $CPUS"
echo "  VNC Port: 590${VNC_PORT}"
echo ""

# Create Lima config
cat > ${OS_NAME}.yaml <<EOF
images:
  - location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
    arch: "aarch64"

cpus: ${CPUS}
memory: "${MEMORY}MiB"
disk: "50GiB"

mounts:
  - location: "~"
    writable: true

provision:
  - mode: system
    script: |
      #!/bin/bash
      set -e
      
      echo "Installing dependencies..."
      apt-get update
      apt-get install -y qemu-system-x86 wget curl nodejs npm bzip2 gzip
      
      echo "Installing code-server..."
      curl -fsSL https://code-server.dev/install.sh | sh
      
      echo "Downloading ${OS_NAME} ISO..."
      mkdir -p /opt/${OS_NAME}
      cd /opt/${OS_NAME}
      wget -q --show-progress ${ISO_URL} || wget ${ISO_URL}
      
      # Decompress if needed
      if ls *.bz2 1> /dev/null 2>&1; then
          echo "Decompressing bz2..."
          bunzip2 *.bz2
      fi
      
      if ls *.gz 1> /dev/null 2>&1; then
          echo "Decompressing gz..."
          gunzip *.gz
      fi
      
      echo "✓ ${OS_NAME} downloaded"
      
  - mode: user
    script: |
      #!/bin/bash
      set -e
      
      echo "Configuring code-server..."
      mkdir -p ~/.config/code-server
      cat > ~/.config/code-server/config.yaml <<INNER_EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${OS_NAME}-dev-2025
cert: false
INNER_EOF
      
      echo "Creating start script..."
      cat > ~/start-${OS_NAME}.sh <<'INNER_EOF'
#!/bin/bash
echo "Starting ${OS_NAME} in QEMU..."
qemu-system-x86_64 \
  -cdrom /opt/${OS_NAME}/*.iso \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -net nic,model=e1000 \
  -net user,hostfwd=tcp::2222-:22 \
  -serial mon:stdio \
  -vnc :${VNC_PORT} \
  -display none
INNER_EOF
      chmod +x ~/start-${OS_NAME}.sh
      
      echo "Creating VNC start script..."
      cat > ~/start-${OS_NAME}-vnc.sh <<'INNER_EOF'
#!/bin/bash
echo "Starting ${OS_NAME} with VNC display..."
qemu-system-x86_64 \
  -cdrom /opt/${OS_NAME}/*.iso \
  -m ${MEMORY} \
  -smp ${CPUS} \
  -net nic,model=e1000 \
  -net user,hostfwd=tcp::2222-:22 \
  -vnc :${VNC_PORT}
INNER_EOF
      chmod +x ~/start-${OS_NAME}-vnc.sh
      
      echo "✓ Configuration complete"
EOF

echo -e "${BLUE}Starting Lima VM...${NC}"
limactl start --name=${OS_NAME} ${OS_NAME}.yaml

# Get VM IP
VM_IP=$(limactl shell ${OS_NAME} hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ${OS_NAME} VM Started!${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Access:"
echo "  code-server: http://${VM_IP}:8080"
echo "  Password: ${OS_NAME}-dev-2025"
echo "  VNC: localhost:590${VNC_PORT}"
echo ""
echo "Start ${OS_NAME}:"
echo "  Console: limactl shell ${OS_NAME} -- ./start-${OS_NAME}.sh"
echo "  VNC: limactl shell ${OS_NAME} -- ./start-${OS_NAME}-vnc.sh &"
echo ""
echo "Stop VM:"
echo "  limactl stop ${OS_NAME}"
echo ""
echo "Delete VM:"
echo "  limactl delete ${OS_NAME}"
echo ""
echo -e "${GREEN}Ready to boot ${OS_NAME}! 🚀${NC}"
echo ""
