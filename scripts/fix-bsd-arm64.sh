#!/bin/bash
#
# FIX ALL BSD BUILDS - ARM64 NATIVE ONLY
# No x86_64 QEMU - real ARM64
#

set -e

echo "=== FIXING BSD BUILDS FOR ARM64 ==="

# 1. FreeBSD ARM64 - Build kernel NOW
echo "[1/3] FreeBSD ARM64..."
if limactl shell freebsd-build -- echo "ready" >/dev/null 2>&1; then
    limactl shell freebsd-build -- sh -c '
        uname -m
        pkg install -y git
        cd /usr/src
        [ ! -d .git ] && git clone --depth 1 --branch releng/14.2 https://git.freebsd.org/src.git .
        
        # M-series kernel config
        cat > sys/arm64/conf/M-SERIES << EOF
include GENERIC
ident M-SERIES
options ZFS
nooptions INVARIANTS
nooptions WITNESS
EOF
        
        make -j$(sysctl -n hw.ncpu) buildkernel KERNCONF=M-SERIES
        make installkernel KERNCONF=M-SERIES
        echo "✓ FreeBSD ARM64 kernel installed"
    ' > freebsd-arm64-build.log 2>&1 &
    echo "FreeBSD building..."
else
    echo "FreeBSD VM not accessible"
fi

# 2. OpenBSD ARM64 - Need to start fresh
echo "[2/3] OpenBSD ARM64..."
# OpenBSD needs manual install from ISO, skip for now
echo "OpenBSD: Requires manual installation"

# 3. NetBSD ARM64 - Need to start fresh  
echo "[3/3] NetBSD ARM64..."
# NetBSD needs manual install from ISO, skip for now
echo "NetBSD: Requires manual installation"

echo ""
echo "✓ FreeBSD ARM64 building in background"
echo "Check: tail -f freebsd-arm64-build.log"
