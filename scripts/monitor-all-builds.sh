#!/bin/sh
#
# Monitor all parallel kernel builds
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║   PARALLEL BUILD MONITOR                 ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

watch_build() {
    while true; do
        clear
        echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
        echo "${MAGENTA}║   PARALLEL KERNEL BUILDS - LIVE STATUS  ║${NC}"
        echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
        echo ""
        echo "${CYAN}Updated: $(date '+%H:%M:%S')${NC}"
        echo ""
        
        # Check each VM
        for vm in alpine-kernel-build freebsd-kernel-build netbsd-arm64 openbsd-kernel-build; do
            if limactl list | grep -q "^$vm"; then
                STATUS=$(limactl list | grep "^$vm" | awk '{print $2}')
                SSH=$(limactl list | grep "^$vm" | awk '{print $3}')
                VMTYPE=$(limactl list | grep "^$vm" | awk '{print $4}')
                
                case "$vm" in
                    alpine*)
                        LABEL="${GREEN}[1] Alpine  ${NC}"
                        ;;
                    freebsd*)
                        LABEL="${GREEN}[2] FreeBSD ${NC}"
                        ;;
                    netbsd*)
                        LABEL="${YELLOW}[3] NetBSD  ${NC}"
                        ;;
                    openbsd*)
                        LABEL="${RED}[4] OpenBSD ${NC}"
                        ;;
                esac
                
                if [ "$STATUS" = "Running" ]; then
                    echo "$LABEL ${GREEN}✓ Running${NC} - $SSH ($VMTYPE)"
                else
                    echo "$LABEL ${YELLOW}○ $STATUS${NC}"
                fi
            else
                case "$vm" in
                    alpine*)
                        echo "${GREEN}[1] Alpine  ${NC} ${RED}✗ Not started${NC}"
                        ;;
                    freebsd*)
                        echo "${GREEN}[2] FreeBSD ${NC} ${RED}✗ Not started${NC}"
                        ;;
                    netbsd*)
                        echo "${YELLOW}[3] NetBSD  ${NC} ${RED}✗ Not started${NC}"
                        ;;
                    openbsd*)
                        echo "${RED}[4] OpenBSD ${NC} ${RED}✗ Not started${NC}"
                        ;;
                esac
            fi
        done
        
        echo ""
        echo "${CYAN}════════════════════════════════════════${NC}"
        echo ""
        echo "Press Ctrl+C to stop monitoring"
        echo ""
        
        sleep 5
    done
}

watch_build
