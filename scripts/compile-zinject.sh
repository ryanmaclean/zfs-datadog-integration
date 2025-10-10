#!/bin/sh
#
# Compile OpenZFS from source with zinject support
# This enables error injection testing
#

set -e

echo "========================================"
echo "OpenZFS Source Compilation with zinject"
echo "========================================"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Install build dependencies
echo "Installing build dependencies..."
apt-get update -qq
apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    gawk \
    alien \
    fakeroot \
    dkms \
    libblkid-dev \
    uuid-dev \
    libudev-dev \
    libssl-dev \
    zlib1g-dev \
    libaio-dev \
    libattr1-dev \
    libelf-dev \
    linux-headers-$(uname -r) \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-cffi \
    libffi-dev \
    git

echo ""
echo "Cloning OpenZFS repository..."
cd /tmp
rm -rf zfs
git clone --depth 1 --branch zfs-2.2.2 https://github.com/openzfs/zfs.git
cd zfs

echo ""
echo "Configuring OpenZFS with debug support (includes zinject)..."
./autogen.sh
./configure --enable-debug

echo ""
echo "Compiling OpenZFS (this may take 15-30 minutes)..."
make -j$(nproc)

echo ""
echo "Installing OpenZFS..."
make install
ldconfig

echo ""
echo "Loading ZFS modules..."
modprobe zfs

echo ""
echo "Verifying zinject installation..."
if command -v zinject >/dev/null 2>&1; then
    echo "✓ zinject successfully installed"
    zinject --help | head -5
else
    echo "✗ zinject not found in PATH"
    echo "Check /usr/local/sbin/zinject"
fi

echo ""
echo "========================================"
echo "OpenZFS compilation complete!"
echo "========================================"
echo ""
echo "zinject is now available for error injection testing"
echo ""
echo "Example usage:"
echo "  zinject -d /dev/disk -e checksum -T read -f 0.1 poolname"
echo ""
echo "To clean up:"
echo "  cd /tmp/zfs && make uninstall"
echo "  apt-get install --reinstall zfsutils-linux"
echo ""
