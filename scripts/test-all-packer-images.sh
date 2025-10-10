#!/usr/bin/env bash
# Test all Packer-built images with ZFS + Datadog

REMOTE="studio@i9-zfs-pop.local"

echo "Testing all Packer-built images..."

ssh $REMOTE "cd /tank3/vms && bash -s" <<'REMOTE_TEST'
#!/bin/bash

for img in output-*/; do
    os=$(basename $img | sed 's/output-//' | sed 's/-zfs//')
    echo "=== Testing $os ==="
    
    # Start VM from image
    qemu-system-x86_64 \
        -m 2048 \
        -smp 2 \
        -drive file=${img}*.qcow2,format=qcow2 \
        -net nic -net user,hostfwd=tcp::2222-:22 \
        -nographic \
        -daemonize
    
    # Wait for SSH
    sleep 30
    
    # Test SSH connection
    ssh -p 2222 -o StrictHostKeyChecking=no root@localhost "
        echo '✓ SSH working'
        zpool list || echo '✗ ZFS not available'
        systemctl status datadog-agent || service datadog-agent status || echo '✗ Datadog not running'
        ls -la /etc/zfs/zed.d/*datadog* || ls -la /usr/local/etc/zfs/zed.d/*datadog* || echo '✗ Zedlets not found'
        
        # Create test pool
        mkdir -p /tmp/zfs-test
        dd if=/dev/zero of=/tmp/zfs-test/disk1.img bs=1M count=256
        dd if=/dev/zero of=/tmp/zfs-test/disk2.img bs=1M count=256
        zpool create -f testpool mirror /tmp/zfs-test/disk1.img /tmp/zfs-test/disk2.img
        
        # Run scrub
        zpool scrub testpool
        sleep 5
        zpool status testpool
    "
    
    # Kill VM
    pkill -f "qemu.*${img}"
    
    echo ""
done
REMOTE_TEST
