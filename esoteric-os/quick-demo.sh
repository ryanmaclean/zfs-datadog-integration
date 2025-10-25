#!/bin/bash
#
# Quick Demo - Boot Plan 9 and show it working
#

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Quick Demo: Plan 9 from Bell Labs                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "This will:"
echo "  1. Boot Plan 9 in a Lima VM"
echo "  2. Install code-server"
echo "  3. Download Plan 9 ISO"
echo "  4. Start QEMU"
echo "  5. Show you how to access it"
echo ""
echo "Time: ~5 minutes"
echo ""
read -p "Continue? (Y/n) " CONTINUE
if [[ $CONTINUE =~ ^[Nn]$ ]]; then
    exit 0
fi

echo ""
echo -e "${BLUE}[1/5] Booting Lima VM...${NC}"
./boot-esoteric.sh plan9

echo ""
echo -e "${BLUE}[2/5] Waiting for VM to be ready...${NC}"
sleep 10

echo ""
echo -e "${BLUE}[3/5] Getting VM info...${NC}"
VM_IP=$(limactl shell plan9 hostname -I | awk '{print $1}')
echo "VM IP: ${VM_IP}"

echo ""
echo -e "${BLUE}[4/5] Starting code-server...${NC}"
limactl shell plan9 -- "nohup code-server > ~/code-server.log 2>&1 &"
sleep 5

echo ""
echo -e "${BLUE}[5/5] Starting Plan 9 in QEMU...${NC}"
echo "Starting in background..."
limactl shell plan9 -- "nohup ~/start-plan9.sh > ~/plan9.log 2>&1 &"
sleep 3

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Plan 9 is Running!                                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Access:"
echo "  code-server: http://${VM_IP}:8080"
echo "  Password: plan9-dev-2025"
echo ""
echo "  VNC (Plan 9 GUI): vnc://localhost:5901"
echo "  (Connect with: open vnc://localhost:5901)"
echo ""
echo "Commands:"
echo "  View logs: limactl shell plan9 -- tail -f ~/plan9.log"
echo "  Stop Plan 9: limactl shell plan9 -- pkill qemu"
echo "  Stop VM: limactl stop plan9"
echo "  Delete VM: limactl delete plan9"
echo ""
echo "Try it:"
echo "  1. Open http://${VM_IP}:8080 in browser"
echo "  2. Enter password: plan9-dev-2025"
echo "  3. Open terminal in code-server"
echo "  4. Run: tail -f ~/plan9.log"
echo "  5. See Plan 9 booting!"
echo ""
echo -e "${GREEN}Demo complete! 🎉${NC}"
echo ""
