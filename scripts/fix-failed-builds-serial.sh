#!/bin/bash
#
# Fix failed builds by accessing VMs directly (bypassing SSH)
#

set -e

echo "=== FIXING FAILED BUILDS - USING DIRECT ACCESS ==="

# For VMs with SSH issues, use limactl copy + execute
fix_build() {
    local VM=$1
    
    echo "[${VM}] Trying direct approach..."
    
    # Create build script locally
    cat > /tmp/build-kernel-${VM}.sh << 'EOF'
#!/bin/bash
set -e
cd /usr/src
[ ! -d linux ] && git clone --depth 1 https://github.com/torvalds/linux.git
cd linux
make mrproper
make defconfig
scripts/config --enable ARM64_CRYPTO
scripts/config --enable CRYPTO_AES_ARM64_CE
scripts/config --enable CRYPTO_SHA256_ARM64
scripts/config --enable CRYPTO_CRC32_ARM64_CE
make olddefconfig
make prepare
make -j$(nproc) Image modules
make modules_install
cp arch/arm64/boot/Image /boot/vmlinuz-m-series
echo "DONE"
EOF
    
    # Copy script to VM
    limactl copy /tmp/build-kernel-${VM}.sh ${VM}:/tmp/build.sh
    
    # Execute via limactl (not shell, direct exec)
    limactl shell ${VM} sudo bash /tmp/build.sh > build-logs-serial/${VM}.log 2>&1 &
    
    echo "[${VM}] Build started via direct copy+exec"
}

mkdir -p build-logs-serial

# Fix the SSH-failed VMs
for VM in debian-zfs rocky-zfs; do
    if limactl list | grep -q "^${VM}.*Running"; then
        fix_build $VM
        sleep 2
    fi
done

echo ""
echo "=== BUILDS RESTARTED ==="
echo "Monitor: tail -f build-logs-serial/*.log"
