#!/bin/bash
#
# BUILD ALL - ROBUST VERSION
# Handles errors, retries, and actually completes
#

set +e  # Don't exit on error

LOGS_DIR="build-logs-robust"
mkdir -p $LOGS_DIR

echo "=== BUILDING ALL ARM64 KERNELS - ROBUST MODE ==="
echo "Started: $(date)"

# Build in each VM
build_in_vm() {
    local VM=$1
    local LOG="$LOGS_DIR/${VM}.log"
    
    echo "[${VM}] Starting build..."
    
    limactl shell $VM -- bash -c '
        # Become root
        sudo su - << "ROOTEOF"
set -x

# Remount /boot as rw if needed
mount -o remount,rw /boot 2>/dev/null || true
mount -o remount,rw / 2>/dev/null || true

# Install deps (ignore errors)
if command -v apt-get >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y 2>/dev/null || true
    apt-get install -y build-essential bc bison flex libssl-dev git 2>/dev/null || true
    apt-get install -y libelf-dev 2>/dev/null || apt-get install -y -t bookworm-backports libelf-dev 2>/dev/null || apt-get install -y -t noble-backports libelf-dev 2>/dev/null || true
elif command -v dnf >/dev/null; then
    dnf install -y gcc make bc bison flex elfutils-libelf-devel openssl-devel git 2>/dev/null || true
fi

# Get kernel
cd /usr/src
[ ! -d linux ] && git clone --depth 1 https://github.com/torvalds/linux.git 2>/dev/null || true
cd linux || exit 1

# Clean
make mrproper 2>/dev/null || true

# Config
make defconfig || exit 1
scripts/config --enable ARM64_CRYPTO || true
scripts/config --enable CRYPTO_AES_ARM64_CE || true
scripts/config --enable CRYPTO_SHA256_ARM64 || true
scripts/config --enable CRYPTO_CRC32_ARM64_CE || true
make olddefconfig || exit 1
make prepare || exit 1

# Build
echo "=== BUILDING KERNEL ==="
make -j$(nproc) Image modules || exit 1

# Install
make modules_install || true
cp arch/arm64/boot/Image /boot/vmlinuz-m-series || exit 1

# Bootloader
update-grub 2>/dev/null || grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true

echo "=== SUCCESS ==="
ls -lh /boot/vmlinuz-m-series
ROOTEOF
' > $LOG 2>&1 &
    
    echo "[${VM}] Background build started (log: $LOG)"
}

# Start all builds
echo ""
for VM in debian-zfs ubuntu-zfs rocky-zfs zfs-test; do
    if limactl list | grep -q "^${VM}.*Running"; then
        build_in_vm $VM
        sleep 2
    fi
done

# FreeBSD
if limactl list | grep -q "freebsd.*Running"; then
    echo "[freebsd-build] Starting..."
    limactl shell freebsd-build -- sh -c '
        sudo su - << "FBSDEOF"
pkg install -y git 2>/dev/null || true
cd /usr/src
[ ! -d .git ] && git clone --depth 1 --branch releng/14.2 https://git.freebsd.org/src.git . || true
cat > sys/arm64/conf/M-SERIES << "EOF"
include GENERIC
ident M-SERIES
options ZFS
nooptions INVARIANTS
nooptions WITNESS
EOF
make -j$(sysctl -n hw.ncpu) buildkernel KERNCONF=M-SERIES || exit 1
make installkernel KERNCONF=M-SERIES || exit 1
echo "=== FREEBSD SUCCESS ==="
FBSDEOF
    ' > $LOGS_DIR/freebsd-build.log 2>&1 &
    echo "[freebsd-build] Background build started"
fi

echo ""
echo "=== ALL BUILDS STARTED ==="
echo ""
echo "Monitor: tail -f $LOGS_DIR/*.log"
echo "Wait: This will take 30-60 minutes"
echo ""

# Wait
wait

# Check results
echo ""
echo "=== RESULTS ==="
for VM in debian-zfs ubuntu-zfs rocky-zfs zfs-test; do
    if [ -f "$LOGS_DIR/${VM}.log" ]; then
        if grep -q "SUCCESS" "$LOGS_DIR/${VM}.log"; then
            SIZE=$(limactl shell $VM -- ls -lh /boot/vmlinuz-m-series 2>/dev/null | awk '{print $5}')
            echo "✓ ${VM}: BUILT ($SIZE)"
        else
            echo "✗ ${VM}: Failed (check log)"
        fi
    fi
done

if grep -q "FREEBSD SUCCESS" "$LOGS_DIR/freebsd-build.log" 2>/dev/null; then
    echo "✓ freebsd-build: BUILT"
else
    echo "✗ freebsd-build: Failed (check log)"
fi

echo ""
echo "=== DONE ==="
echo "Finished: $(date)"
