#!/usr/bin/env bash
#
# Setup VMs on ZFS Pool for Multi-OS Testing
# Target: i9-zfs-pop.local with tank3 ZFS pool
#

set -e

REMOTE_HOST="i9-zfs-pop.local"
REMOTE_USER="studio"
ZFS_POOL="tank3"
VM_DATASET="${ZFS_POOL}/vms"
VM_PATH="/tank3/vms"

echo "========================================"
echo "🖥️  Multi-OS VM Setup on ZFS"
echo "========================================"
echo ""
echo "Target: ${REMOTE_USER}@${REMOTE_HOST}"
echo "ZFS Pool: ${ZFS_POOL}"
echo "VM Storage: ${VM_DATASET}"
echo ""

# Install virtualization tools
echo "Step 1: Installing virtualization tools..."
ssh -t ${REMOTE_USER}@${REMOTE_HOST} "sudo bash -c '
apt-get update -qq
apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virtinst
systemctl enable --now libvirtd
usermod -aG libvirt,kvm ${REMOTE_USER}
'"

# Create ZFS dataset for VMs
echo ""
echo "Step 2: Creating ZFS dataset for VMs..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo zfs create -o mountpoint=${VM_PATH} ${VM_DATASET} 2>/dev/null || echo 'Dataset may already exist'"
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo chown -R ${REMOTE_USER}:${REMOTE_USER} ${VM_PATH}"

# Configure libvirt to use ZFS storage
echo ""
echo "Step 3: Configuring libvirt storage pool..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
virsh pool-define-as zfs-vms dir --target ${VM_PATH} 2>/dev/null || true
virsh pool-start zfs-vms 2>/dev/null || true
virsh pool-autostart zfs-vms 2>/dev/null || true
virsh pool-list
"

# Download ISOs to ZFS
echo ""
echo "Step 4: Downloading OS ISOs to ZFS storage..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${VM_PATH}/isos"

# Copy already downloaded ISOs from Mac
echo ""
echo "Step 5: Copying ISOs from local machine..."
scp truenas-scale.iso truenas-core.iso ${REMOTE_USER}@${REMOTE_HOST}:${VM_PATH}/isos/ 2>/dev/null || echo "ISOs not found locally, will download on remote"

# Download remaining ISOs on remote
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${VM_PATH}/isos && bash" <<'DOWNLOAD_ISOS'
# FreeBSD
if [ ! -f FreeBSD-14.3-RELEASE-amd64-disc1.iso ]; then
    echo "Downloading FreeBSD..."
    wget -q --show-progress https://download.freebsd.org/releases/ISO-IMAGES/14.3/FreeBSD-14.3-RELEASE-amd64-disc1.iso
fi

# OpenBSD
if [ ! -f openbsd-7.6-amd64.iso ]; then
    echo "Downloading OpenBSD..."
    wget -q --show-progress https://cdn.openbsd.org/pub/OpenBSD/7.6/amd64/install76.iso -O openbsd-7.6-amd64.iso
fi

# NetBSD
if [ ! -f NetBSD-10.0-amd64.iso ]; then
    echo "Downloading NetBSD..."
    wget -q --show-progress https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/images/NetBSD-10.0-amd64.iso
fi

# OpenIndiana
if [ ! -f openindiana-hipster.iso ]; then
    echo "Downloading OpenIndiana..."
    wget -q --show-progress https://dlc.openindiana.org/isos/hipster/20231030/OI-hipster-text-20231030.iso -O openindiana-hipster.iso
fi

echo "ISOs ready:"
ls -lh *.iso
DOWNLOAD_ISOS

echo ""
echo "Step 6: Creating VM definitions..."

# Create VM creation script on remote
ssh ${REMOTE_USER}@${REMOTE_HOST} "cat > ${VM_PATH}/create-vms.sh" <<'CREATE_VMS'
#!/bin/bash
VM_PATH="/tank3/vms"
ISO_PATH="${VM_PATH}/isos"

# FreeBSD VM
virt-install \
  --name freebsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/freebsd-zfs.qcow2,size=20 \
  --cdrom ${ISO_PATH}/FreeBSD-14.3-RELEASE-amd64-disc1.iso \
  --os-variant freebsd14.0 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# TrueNAS SCALE VM
virt-install \
  --name truenas-scale \
  --memory 8192 \
  --vcpus 2 \
  --disk path=${VM_PATH}/truenas-scale.qcow2,size=20 \
  --cdrom ${ISO_PATH}/truenas-scale.iso \
  --os-variant linux2022 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# TrueNAS CORE VM
virt-install \
  --name truenas-core \
  --memory 8192 \
  --vcpus 2 \
  --disk path=${VM_PATH}/truenas-core.qcow2,size=20 \
  --cdrom ${ISO_PATH}/truenas-core.iso \
  --os-variant freebsd13.0 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# OpenBSD VM
virt-install \
  --name openbsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/openbsd-zfs.qcow2,size=20 \
  --cdrom ${ISO_PATH}/openbsd-7.6-amd64.iso \
  --os-variant openbsd7.0 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# NetBSD VM
virt-install \
  --name netbsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/netbsd-zfs.qcow2,size=20 \
  --cdrom ${ISO_PATH}/NetBSD-10.0-amd64.iso \
  --os-variant netbsd9.0 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# OpenIndiana VM
virt-install \
  --name openindiana-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/openindiana-zfs.qcow2,size=20 \
  --cdrom ${ISO_PATH}/openindiana-hipster.iso \
  --os-variant solaris11 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

echo "VMs created. List:"
virsh list --all
CREATE_VMS

ssh ${REMOTE_USER}@${REMOTE_HOST} "chmod +x ${VM_PATH}/create-vms.sh"

echo ""
echo "========================================"
echo "✅ Setup Complete"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. SSH to ${REMOTE_HOST}"
echo "2. Run: ${VM_PATH}/create-vms.sh"
echo "3. Access VMs via VNC or virt-manager"
echo "4. Complete OS installations"
echo "5. Test zedlets on each OS"
echo ""
echo "VM storage location: ${VM_PATH}"
echo "All VMs stored on ZFS pool: ${ZFS_POOL}"
echo ""
echo "Check VMs: ssh ${REMOTE_USER}@${REMOTE_HOST} 'virsh list --all'"
