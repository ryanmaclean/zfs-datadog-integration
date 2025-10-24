#!/bin/bash
#
# Build OpenBSD M-series kernel NOW
# Most experimental - ZFS unsupported on OpenBSD
#

set -e

echo "=== Building OpenBSD M-series Kernel NOW ==="
echo "WARNING: OpenBSD + ZFS is EXPERIMENTAL"
echo "ZFS has license conflicts with OpenBSD"
date

VM="openbsd-kernel-build"

# Wait for VM
echo "Waiting for OpenBSD VM..."
MAX_WAIT=300
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if limactl shell $VM -- echo "ready" >/dev/null 2>&1; then
        echo "✓ VM ready!"
        break
    fi
    echo "Waiting... ($ELAPSED/$MAX_WAIT)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "ERROR: OpenBSD VM not ready"
    echo "OpenBSD requires manual installation from ISO"
    exit 1
fi

# Build OpenBSD kernel
cat > /tmp/build-openbsd-m-kernel.sh << 'OBSD'
#!/bin/sh
set -ex

echo "=== OpenBSD M-series Kernel Build ==="
uname -a

# Get OpenBSD source
cd /usr/src
if [ ! -d sys ]; then
    ftp https://cdn.openbsd.org/pub/OpenBSD/7.6/sys.tar.gz
    tar xzf sys.tar.gz
    rm sys.tar.gz
fi

# Create M-series kernel config
cat > sys/arch/arm64/conf/M-SERIES << 'EOF'
include "arch/arm64/conf/GENERIC"

ident M-SERIES

# M-series optimizations
maxusers 64
option NKMEMPAGES_MAX_DEFAULT="(128*1024)"

# Performance
option INSECURE

# NVMe
nvme* at pci?

# Note: ZFS not included due to license conflict
# OpenBSD uses CDDL-incompatible license
# ZFS requires CDDL license
EOF

# Build kernel
cd /usr/src/sys/arch/arm64/conf
config M-SERIES

cd ../compile/M-SERIES
echo "Building kernel..."
make -j$(sysctl -n hw.ncpu)

# Install
make install

echo "=== OPENBSD KERNEL BUILD COMPLETE ==="
ls -lh /bsd

# Note about ZFS
cat << 'NOTE'

=====================================
NOTE: ZFS on OpenBSD
=====================================

OpenBSD does NOT officially support ZFS due to:
- License incompatibility (CDDL vs OpenBSD)
- Kernel design differences
- Community philosophy

This kernel does NOT include ZFS.

If you want ZFS, use FreeBSD or Linux.

This build is for demonstration of
M-series optimization on OpenBSD only.
=====================================
NOTE
OBSD

# Copy and execute
echo "Copying build script..."
limactl copy /tmp/build-openbsd-m-kernel.sh $VM:/tmp/

echo "Building OpenBSD kernel (15-30 minutes)..."
limactl shell $VM -- sudo sh /tmp/build-openbsd-m-kernel.sh

echo ""
echo "✓ OpenBSD M-series kernel built!"
echo ""
echo "NOTE: NO ZFS - OpenBSD license incompatible"
echo ""
echo "Next: Reboot OpenBSD VM"
echo "  limactl shell $VM -- sudo shutdown -r now"
