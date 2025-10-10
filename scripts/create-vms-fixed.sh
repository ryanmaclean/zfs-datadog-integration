#!/usr/bin/env bash
#
# Create VMs with sudo (fixes permission issues)
#

REMOTE="studio@i9-zfs-pop.local"

echo "Creating VMs on i9-zfs-pop with proper permissions..."

ssh -t $REMOTE "sudo bash -s" <<'REMOTE_SCRIPT'
VM_PATH="/tank3/vms"
ISO_PATH="${VM_PATH}/isos"

# Create VMs as root to avoid permission issues
echo "Creating FreeBSD VM..."
virt-install \
  --connect qemu:///system \
  --name freebsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/freebsd-zfs.qcow2,size=20,bus=virtio \
  --cdrom ${ISO_PATH}/FreeBSD-14.3-RELEASE-amd64-disc1.iso \
  --os-variant freebsd14.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5901 \
  --noautoconsole &

echo "Creating TrueNAS SCALE VM..."
virt-install \
  --connect qemu:///system \
  --name truenas-scale \
  --memory 8192 \
  --vcpus 2 \
  --disk path=${VM_PATH}/truenas-scale.qcow2,size=20,bus=virtio \
  --cdrom ${ISO_PATH}/truenas-scale.iso \
  --os-variant linux2022 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5902 \
  --noautoconsole &

echo "Creating TrueNAS CORE VM..."
virt-install \
  --connect qemu:///system \
  --name truenas-core \
  --memory 8192 \
  --vcpus 2 \
  --disk path=${VM_PATH}/truenas-core.qcow2,size=20,bus=virtio \
  --cdrom ${ISO_PATH}/truenas-core.iso \
  --os-variant freebsd13.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5903 \
  --noautoconsole &

echo "Creating OpenBSD VM..."
virt-install \
  --connect qemu:///system \
  --name openbsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/openbsd-zfs.qcow2,size=20,bus=virtio \
  --cdrom ${ISO_PATH}/openbsd-7.6.iso \
  --os-variant openbsd7.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5904 \
  --noautoconsole &

echo "Creating NetBSD VM..."
virt-install \
  --connect qemu:///system \
  --name netbsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=${VM_PATH}/netbsd-zfs.qcow2,size=20,bus=virtio \
  --cdrom ${ISO_PATH}/NetBSD-10.0-amd64.iso \
  --os-variant netbsd9.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5905 \
  --noautoconsole &

wait
echo ""
echo "VMs created!"
virsh list --all
REMOTE_SCRIPT

echo ""
echo "✅ All VMs created!"
echo ""
echo "Access via VNC:"
echo "  FreeBSD:       i9-zfs-pop.local:5901"
echo "  TrueNAS SCALE: i9-zfs-pop.local:5902"
echo "  TrueNAS CORE:  i9-zfs-pop.local:5903"
echo "  OpenBSD:       i9-zfs-pop.local:5904"
echo "  NetBSD:        i9-zfs-pop.local:5905"
echo ""
echo "Start VMs: ssh studio@i9-zfs-pop.local 'sudo virsh start <vm-name>'"
