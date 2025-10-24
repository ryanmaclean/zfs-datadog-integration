#!/bin/bash
#
# BUILD ALL ARM64 IMAGES AND KERNELS AT ONCE
# Parallel execution across all platforms
#

set -e

echo "=== BUILDING ALL ARM64 IMAGES AND KERNELS ==="
echo "Started: $(date)"

LOGS_DIR="build-logs"
mkdir -p $LOGS_DIR

# Function to build kernel in VM
build_kernel() {
    local VM=$1
    local LOG="$LOGS_DIR/${VM}-kernel.log"
    
    echo "[${VM}] Building kernel..."
    
    limactl shell $VM -- sudo bash -c '
        set -e
        
        # Install tools (handle different distros)
        if command -v apt-get >/dev/null 2>&1; then
            # Debian/Ubuntu
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y build-essential bc bison flex libssl-dev git curl wget
            # Fix libelf-dev on Debian
            apt-get install -y --fix-broken || true
            apt-get install -y libelf-dev || apt-get install -y -t bookworm-backports libelf-dev || apt-get install -y -t noble-backports libelf-dev || true
        elif command -v dnf >/dev/null 2>&1; then
            # Rocky/RHEL
            dnf install -y epel-release
            dnf config-manager --set-enabled crb || dnf config-manager --set-enabled powertools || true
            dnf install -y gcc make bc bison flex elfutils-libelf-devel openssl-devel git curl wget kernel-devel
        fi
        
        # Get kernel
        cd /usr/src
        if [ ! -d linux ]; then
            git clone --depth 1 https://github.com/torvalds/linux.git
        fi
        cd linux
        
        # Clean any previous failed builds
        make mrproper || true
        
        # Configure for M-series
        make defconfig
        scripts/config --enable ARM64_CRYPTO
        scripts/config --enable CRYPTO_AES_ARM64_CE
        scripts/config --enable CRYPTO_SHA256_ARM64
        scripts/config --enable CRYPTO_CRC32_ARM64_CE
        
        # CRITICAL: Generate config files
        make olddefconfig
        make prepare
        
        # Build
        make -j$(nproc) Image modules
        make modules_install
        cp arch/arm64/boot/Image /boot/vmlinuz-m-series
        
        # Update bootloader
        if command -v update-grub >/dev/null 2>&1; then
            update-grub
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
        
        echo "KERNEL BUILT: $(ls -lh /boot/vmlinuz-m-series)"
    ' > $LOG 2>&1 &
    
    echo "[${VM}] Building in background (log: $LOG)"
}

# Function to build FreeBSD kernel
build_freebsd_kernel() {
    local VM=$1
    local LOG="$LOGS_DIR/${VM}-kernel.log"
    
    echo "[${VM}] Building FreeBSD kernel..."
    
    # Wait for FreeBSD to be accessible
    for i in {1..10}; do
        if limactl shell $VM -- echo "ready" >/dev/null 2>&1; then
            break
        fi
        echo "[${VM}] Waiting for SSH... ($i/10)"
        sleep 5
    done
    
    limactl shell $VM -- sudo sh -c '
        set -e
        
        # Install git if needed
        pkg update || true
        pkg install -y git || true
        
        # Get source
        cd /usr/src
        if [ ! -d .git ]; then
            git clone --depth 1 --branch releng/14.2 https://git.freebsd.org/src.git .
        fi
        
        # Create M-SERIES config
        cat > sys/arm64/conf/M-SERIES << "EOF"
include GENERIC
ident M-SERIES
options ZFS
nooptions INVARIANTS
nooptions WITNESS
nooptions DDB
EOF
        
        # Build
        make -j$(sysctl -n hw.ncpu) buildkernel KERNCONF=M-SERIES
        make installkernel KERNCONF=M-SERIES
        
        echo "FREEBSD KERNEL BUILT"
    ' > $LOG 2>&1 &
    
    echo "[${VM}] Building in background (log: $LOG)"
}

echo ""
echo "=== STARTING ALL KERNEL BUILDS ==="
echo ""

# Linux kernels (parallel)
for VM in debian-zfs ubuntu-zfs rocky-zfs zfs-test; do
    if limactl list | grep -q "^${VM}.*Running"; then
        build_kernel $VM
    else
        echo "[${VM}] Not running, skipping"
    fi
done

# FreeBSD kernel
if limactl list | grep -q "^freebsd.*Running"; then
    build_freebsd_kernel freebsd-build
else
    echo "[freebsd-build] Not running, skipping"
fi

echo ""
echo "=== ALL KERNEL BUILDS STARTED ==="
echo ""
echo "Monitor with:"
echo "  tail -f $LOGS_DIR/*.log"
echo ""
echo "Or check individual:"
for LOG in $LOGS_DIR/*-kernel.log; do
    [ -f "$LOG" ] && echo "  tail -f $LOG"
done

echo ""
echo "Waiting for builds to complete..."
echo "(This takes 30-60 minutes per build)"
echo ""

# Wait for all background jobs
wait

echo ""
echo "=== CHECKING RESULTS ==="
echo ""

# Check each VM
for VM in debian-zfs ubuntu-zfs rocky-zfs zfs-test; do
    if limactl list | grep -q "^${VM}.*Running"; then
        KERNEL=$(limactl shell $VM -- ls -lh /boot/vmlinuz-m-series 2>/dev/null | awk '{print $5}')
        if [ -n "$KERNEL" ]; then
            echo "✓ ${VM}: Kernel built ($KERNEL)"
        else
            echo "✗ ${VM}: Build may have failed"
        fi
    fi
done

# FreeBSD
if limactl list | grep -q "^freebsd.*Running"; then
    if limactl shell freebsd-build -- test -f /boot/kernel/kernel 2>/dev/null; then
        echo "✓ freebsd-build: Kernel built"
    else
        echo "✗ freebsd-build: Build may have failed"
    fi
fi

echo ""
echo "=== BUILD COMPLETE ==="
echo "Finished: $(date)"
echo ""
echo "Next steps:"
echo "1. Reboot VMs to load custom kernels"
echo "2. Verify with: limactl shell <vm> -- uname -r"
echo "3. Test ZFS with custom kernels"
echo "4. Extract and publish images"
