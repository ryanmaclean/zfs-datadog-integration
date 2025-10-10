#!/usr/bin/env bash
#
# Quick VM Setup - Creates VMs with cloud-init for automation
# Uses cloud images where available for faster setup
#

REMOTE="studio@i9-zfs-pop.local"

echo "Setting up VMs with automation..."

# Create cloud-init config
cat > user-data <<'EOF'
#cloud-config
users:
  - name: root
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... # Add your SSH key
    lock_passwd: false
    passwd: $6$rounds=4096$saltsalt$hashedpassword
packages:
  - curl
  - wget
runcmd:
  - echo "VM ready for testing"
EOF

# Copy to server
scp user-data $REMOTE:/tank3/vms/

# Create VMs on server
ssh $REMOTE "bash -s" <<'REMOTE_SCRIPT'
cd /tank3/vms

# FreeBSD (use cloud image if available)
sudo virt-install \
  --name freebsd-zfs \
  --memory 4096 --vcpus 2 \
  --disk path=/tank3/vms/freebsd-zfs.qcow2,size=20 \
  --location /tank3/vms/isos/FreeBSD-14.3-RELEASE-amd64-disc1.iso \
  --os-variant freebsd14.0 \
  --network network=default,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --extra-args 'console=ttyS0,115200n8 serial' \
  --noautoconsole &

# TrueNAS SCALE
sudo virt-install \
  --name truenas-scale \
  --memory 8192 --vcpus 2 \
  --disk path=/tank3/vms/truenas-scale.qcow2,size=20 \
  --cdrom /tank3/vms/isos/truenas-scale.iso \
  --os-variant linux2022 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5902 \
  --noautoconsole &

# TrueNAS CORE
sudo virt-install \
  --name truenas-core \
  --memory 8192 --vcpus 2 \
  --disk path=/tank3/vms/truenas-core.qcow2,size=20 \
  --cdrom /tank3/vms/isos/truenas-core.iso \
  --os-variant freebsd13.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5903 \
  --noautoconsole &

wait
echo "VMs created. Check status:"
sudo virsh list --all
REMOTE_SCRIPT

echo ""
echo "✅ VMs created on i9-zfs-pop.local"
echo ""
echo "Next: Complete installations via VNC, then run:"
echo "  ./parallel-vm-test.sh"
