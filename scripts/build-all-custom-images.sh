#!/bin/bash
#
# Build ALL custom images for M-series
# Arch, Gentoo, NetBSD, OpenBSD
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  BUILD ALL CUSTOM M-SERIES IMAGES       ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

BUILD_DIR="/tmp/m-series-builds"
mkdir -p "$BUILD_DIR"

# Track what we build
BUILDS_STARTED=0
BUILDS_COMPLETED=0

# ============================================================================
# 1. ARCH LINUX
# ============================================================================

echo "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo "${CYAN}║  [1/4] Arch Linux M-series               ║${NC}"
echo "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo "${CYAN}Starting Arch build in background...${NC}"
sudo ./iso-builds/build-arch-m-series-iso.sh > "$BUILD_DIR/arch-build.log" 2>&1 &
ARCH_PID=$!
echo "${GREEN}✓ Arch build started (PID: $ARCH_PID)${NC}"
BUILDS_STARTED=$((BUILDS_STARTED + 1))

# ============================================================================
# 2. GENTOO
# ============================================================================

echo ""
echo "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo "${CYAN}║  [2/4] Gentoo M-series (Source-based)   ║${NC}"
echo "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo "${CYAN}Starting Gentoo build in background...${NC}"
echo "${YELLOW}Note: This takes 2-3 hours (compiling everything)${NC}"
sudo ./iso-builds/build-gentoo-m-series-iso.sh > "$BUILD_DIR/gentoo-build.log" 2>&1 &
GENTOO_PID=$!
echo "${GREEN}✓ Gentoo build started (PID: $GENTOO_PID)${NC}"
BUILDS_STARTED=$((BUILDS_STARTED + 1))

# ============================================================================
# 3. NETBSD
# ============================================================================

echo ""
echo "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo "${CYAN}║  [3/4] NetBSD M-series                   ║${NC}"
echo "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo "${CYAN}Starting NetBSD build in background...${NC}"
sudo ./iso-builds/build-netbsd-m-series-iso.sh > "$BUILD_DIR/netbsd-build.log" 2>&1 &
NETBSD_PID=$!
echo "${GREEN}✓ NetBSD build started (PID: $NETBSD_PID)${NC}"
BUILDS_STARTED=$((BUILDS_STARTED + 1))

# ============================================================================
# 4. OPENBSD
# ============================================================================

echo ""
echo "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo "${CYAN}║  [4/4] OpenBSD M-series (Experimental)   ║${NC}"
echo "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo "${CYAN}Starting OpenBSD build in background...${NC}"
sudo ./iso-builds/build-openbsd-m-series-iso.sh > "$BUILD_DIR/openbsd-build.log" 2>&1 &
OPENBSD_PID=$!
echo "${GREEN}✓ OpenBSD build started (PID: $OPENBSD_PID)${NC}"
BUILDS_STARTED=$((BUILDS_STARTED + 1))

# ============================================================================
# MONITOR BUILDS
# ============================================================================

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║  ALL BUILDS RUNNING IN PARALLEL!        ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

echo "${CYAN}Build PIDs:${NC}"
echo "  Arch:    $ARCH_PID"
echo "  Gentoo:  $GENTOO_PID"
echo "  NetBSD:  $NETBSD_PID"
echo "  OpenBSD: $OPENBSD_PID"
echo ""

echo "${CYAN}Monitor logs:${NC}"
echo "  tail -f $BUILD_DIR/arch-build.log"
echo "  tail -f $BUILD_DIR/gentoo-build.log"
echo "  tail -f $BUILD_DIR/netbsd-build.log"
echo "  tail -f $BUILD_DIR/openbsd-build.log"
echo ""

echo "${CYAN}Expected completion times:${NC}"
echo "  Arch:    ~40 minutes"
echo "  NetBSD:  ~30 minutes"
echo "  OpenBSD: ~25 minutes"
echo "  Gentoo:  ~2-3 hours (everything from source!)"
echo ""

echo "${YELLOW}Waiting for builds to complete...${NC}"
echo "${YELLOW}Press Ctrl+C to stop monitoring (builds continue)${NC}"
echo ""

# Monitor completion
while true; do
    sleep 30
    
    # Check each build
    if ! ps -p $ARCH_PID > /dev/null 2>&1; then
        if [ ! -f "$BUILD_DIR/arch-done" ]; then
            echo "${GREEN}✓ Arch build completed!${NC}"
            touch "$BUILD_DIR/arch-done"
            BUILDS_COMPLETED=$((BUILDS_COMPLETED + 1))
        fi
    fi
    
    if ! ps -p $NETBSD_PID > /dev/null 2>&1; then
        if [ ! -f "$BUILD_DIR/netbsd-done" ]; then
            echo "${GREEN}✓ NetBSD build completed!${NC}"
            touch "$BUILD_DIR/netbsd-done"
            BUILDS_COMPLETED=$((BUILDS_COMPLETED + 1))
        fi
    fi
    
    if ! ps -p $OPENBSD_PID > /dev/null 2>&1; then
        if [ ! -f "$BUILD_DIR/openbsd-done" ]; then
            echo "${GREEN}✓ OpenBSD build completed!${NC}"
            touch "$BUILD_DIR/openbsd-done"
            BUILDS_COMPLETED=$((BUILDS_COMPLETED + 1))
        fi
    fi
    
    if ! ps -p $GENTOO_PID > /dev/null 2>&1; then
        if [ ! -f "$BUILD_DIR/gentoo-done" ]; then
            echo "${GREEN}✓ Gentoo build completed!${NC}"
            touch "$BUILD_DIR/gentoo-done"
            BUILDS_COMPLETED=$((BUILDS_COMPLETED + 1))
        fi
    fi
    
    # All done?
    if [ $BUILDS_COMPLETED -eq $BUILDS_STARTED ]; then
        break
    fi
    
    echo "Status: $BUILDS_COMPLETED/$BUILDS_STARTED builds complete..."
done

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "${MAGENTA}╔══════════════════════════════════════════╗${NC}"
echo "${MAGENTA}║          ALL BUILDS COMPLETE!            ║${NC}"
echo "${MAGENTA}╚══════════════════════════════════════════╝${NC}"
echo ""

echo "${CYAN}Custom ISOs built:${NC}"
ls -lh /tmp/*/arch-m-series-*.iso 2>/dev/null || echo "  Arch: Check logs"
ls -lh /tmp/*/gentoo-m-series-*.iso 2>/dev/null || echo "  Gentoo: Check logs"
ls -lh /tmp/*/netbsd-m-series-*.iso 2>/dev/null || echo "  NetBSD: Check logs"
ls -lh /tmp/*/openbsd-m-series-*.iso 2>/dev/null || echo "  OpenBSD: Check logs"

echo ""
echo "${GREEN}✓ Custom M-series images ready!${NC}"
echo ""
echo "Next: Install them with Lima or test on bare metal ARM64"
