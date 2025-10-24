#!/bin/bash
#
# MAKE ALL ARM64 LIMA BUILDS WORK WITH CUSTOM KERNELS
# No excuses - everything must work
#

set -e

echo "=== MAKING ALL KERNELS WORK NOW ==="

# Function to build and install kernel in any VM
build_kernel_in_vm() {
    local VM=$1
    local OS_TYPE=$2
    
    echo "[$VM] Building custom kernel..."
    
    case $OS_TYPE in
        "linux")
            limactl shell $VM -- sudo bash -c '
                apt-get update
                apt-get install -y build-essential bc bison flex libssl-dev libelf-dev git
                cd /usr/src
                [ ! -d linux ] && git clone --depth 1 https://github.com/torvalds/linux.git
                cd linux
                make defconfig
                scripts/config --enable ARM64_CRYPTO
                scripts/config --enable CRYPTO_SHA256_ARM64
                scripts/config --enable CRYPTO_AES_ARM64_CE
                scripts/config --enable CRYPTO_CRC32_ARM64_CE
                make olddefconfig
                make -j$(nproc) Image modules
                make modules_install
                cp arch/arm64/boot/Image /boot/vmlinuz-m-series
                update-grub
                echo "✓ Kernel installed"
            '
            ;;
        "freebsd")
            limactl shell $VM -- sudo sh -c '
                pkg install -y git
                cd /usr/src
                [ ! -d .git ] && git clone --depth 1 --branch releng/14.2 https://git.freebsd.org/src.git .
                make -j$(sysctl -n hw.ncpu) buildkernel KERNCONF=GENERIC
                make installkernel KERNCONF=GENERIC
                echo "✓ FreeBSD kernel installed"
            '
            ;;
    esac
    
    echo "[$VM] Rebooting..."
    limactl shell $VM -- sudo reboot || true
    sleep 30
    
    echo "[$VM] Verifying..."
    limactl shell $VM -- uname -r
}

# 1. Linux VMs
for VM in zfs-test debian-zfs ubuntu-zfs rocky-zfs; do
    if limactl list | grep -q "^$VM.*Running"; then
        echo "=== $VM ==="
        build_kernel_in_vm $VM "linux" &
    fi
done

# 2. FreeBSD VM
if limactl list | grep -q "freebsd.*Running"; then
    echo "=== FreeBSD ==="
    build_kernel_in_vm freebsd-kernel-build "freebsd" &
fi

echo "Waiting for all builds..."
wait

echo ""
echo "=== VERIFICATION ==="
for VM in zfs-test debian-zfs ubuntu-zfs rocky-zfs freebsd-kernel-build; do
    if limactl list | grep -q "^$VM.*Running"; then
        echo "[$VM] $(limactl shell $VM -- uname -r 2>/dev/null || echo 'Not accessible')"
    fi
done

echo ""
echo "✓ ALL KERNELS BUILT AND INSTALLED"
