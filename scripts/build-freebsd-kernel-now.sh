#!/bin/bash
#
# Build FreeBSD M-series kernel NOW
# Fresh start, no SSH issues
#

set -e

echo "=== Building FreeBSD M-series Kernel NOW ==="
date

VM="freebsd-build"

# Wait for VM to be ready
echo "Waiting for FreeBSD VM..."
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
    echo "ERROR: VM not ready"
    exit 1
fi

# Create FreeBSD kernel build script
cat > /tmp/build-freebsd-m-kernel.sh << 'FBSD'
#!/bin/sh
set -ex

echo "=== FreeBSD M-series Kernel Build ==="
uname -a

# Install build tools
pkg update
pkg install -y git

# Get FreeBSD source
cd /usr/src
if [ ! -d .git ]; then
    git clone --depth 1 --branch releng/14.2 https://git.freebsd.org/src.git .
fi

# Create M-series kernel config
cat > sys/arm64/conf/M-SERIES << 'EOF'
include GENERIC

ident M-SERIES

# Remove debug for performance
nooptions INVARIANTS
nooptions WITNESS
nooptions DDB

# M-series optimizations
options MAXCPU=16
options VM_KMEM_SIZE_SCALE=1

# Native ZFS
options ZFS

# NVMe only
device nvme
device nvd

# Remove legacy
nodevice ahci
nodevice ada
EOF

# Build kernel
echo "Building M-series kernel..."
make -j$(sysctl -n hw.ncpu) KERNCONF=M-SERIES buildkernel

# Install kernel
echo "Installing M-series kernel..."
make KERNCONF=M-SERIES installkernel

# Configure loader
cat >> /boot/loader.conf << 'EOF'

# M-series optimizations
hw.ncpu=16
kern.smp.maxcpus=16
vfs.zfs.arc_max=8589934592
vfs.zfs.arc_min=2147483648
EOF

echo "=== FREEBSD KERNEL BUILD COMPLETE ==="
ls -lh /boot/kernel/kernel
FBSD

# Copy and execute
echo "Copying build script..."
limactl copy /tmp/build-freebsd-m-kernel.sh $VM:/tmp/

echo "Building FreeBSD kernel (30-45 minutes)..."
limactl shell $VM -- sudo sh /tmp/build-freebsd-m-kernel.sh

echo ""
echo "✓ FreeBSD M-series kernel built!"
echo ""
echo "Next: Reboot FreeBSD VM"
echo "  limactl shell $VM -- sudo shutdown -r now"
