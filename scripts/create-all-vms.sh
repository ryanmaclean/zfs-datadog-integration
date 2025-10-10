#!/usr/bin/env bash
#
# Create All Test VMs on i9-zfs-pop
# Fast testing with small pools instead of waiting for 87TB scrub
#

REMOTE="studio@i9-zfs-pop.local"
VM_PATH="/tank3/vms"
ISO_PATH="${VM_PATH}/isos"

echo "Creating all test VMs on i9-zfs-pop..."
echo ""

# Create VMs via SSH
ssh $REMOTE "bash -s" <<'REMOTE_SCRIPT'
VM_PATH="/tank3/vms"
ISO_PATH="${VM_PATH}/isos"

# FreeBSD
echo "Creating FreeBSD VM..."
virt-install \
  --name freebsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/freebsd-zfs.qcow2,size=20 \
  --cdrom ${ISO_PATH}/FreeBSD-14.3-RELEASE-amd64-disc1.iso \
  --os-variant freebsd14.0 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0,port=5901 \
  --noautoconsole &

# TrueNAS SCALE
echo "Creating TrueNAS SCALE VM..."
virt-install \
  --name truenas-scale \
  --memory 8192 \
  --vcpus 2 \
  --disk path=${VM_PATH}/truenas-scale.qcow2,size=20 \
  --cdrom ${ISO_PATH}/truenas-scale.iso \
  --os-variant linux2022 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0,port=5902 \
  --noautoconsole &

# TrueNAS CORE
echo "Creating TrueNAS CORE VM..."
virt-install \
  --name truenas-core \
  --memory 8192 \
  --vcpus 2 \
  --disk path=${VM_PATH}/truenas-core.qcow2,size=20 \
  --cdrom ${ISO_PATH}/truenas-core.iso \
  --os-variant freebsd13.0 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0,port=5903 \
  --noautoconsole &

wait
echo "VMs created!"
virsh list --all
REMOTE_SCRIPT

echo ""
echo "VMs created on i9-zfs-pop.local"
echo "Access via VNC:"
echo "  FreeBSD: i9-zfs-pop.local:5901"
echo "  TrueNAS SCALE: i9-zfs-pop.local:5902"
echo "  TrueNAS CORE: i9-zfs-pop.local:5903"
