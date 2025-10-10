#!/usr/bin/env bash
# Automate Lima VM testing for all OSes

set -e

VMS="debian-zfs rocky-zfs ubuntu-zfs"

echo "=== Automating Lima VM Testing ==="

# Start fedora if stopped
echo "Starting fedora-zfs..."
limactl start fedora-zfs 2>/dev/null || echo "fedora-zfs already running or failed"

# Install ZFS on rocky-zfs
echo "Installing ZFS on rocky-zfs..."
limactl shell rocky-zfs sudo dnf install -y epel-release
limactl shell rocky-zfs sudo dnf install -y kernel-devel
limactl shell rocky-zfs 'sudo dnf install -y https://zfsonlinux.org/epel/zfs-release-2-3.el9.noarch.rpm'
limactl shell rocky-zfs sudo dnf install -y zfs

# Deploy zedlets to all VMs
for vm in $VMS; do
    echo "=== Deploying to $vm ==="
    
    # Copy files
    limactl copy install.sh $vm:/tmp/
    limactl copy config.sh $vm:/tmp/
    limactl copy zfs-datadog-lib.sh $vm:/tmp/
    limactl copy *-datadog.sh $vm:/tmp/
    limactl copy .env.local $vm:/tmp/
    
    # Install
    limactl shell $vm sudo bash /tmp/install.sh
    
    # Create test pool
    limactl shell $vm 'sudo mkdir -p /tmp/zfs-test && \
        sudo dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=256 && \
        sudo dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=256 && \
        sudo zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img'
    
    # Run scrub
    limactl shell $vm sudo zpool scrub testpool
    sleep 5
    limactl shell $vm sudo zpool status testpool
    
    echo "✓ $vm complete"
done

echo "=== All Lima VMs tested ==="
