# Multi-OS Testing on i9-zfs-pop with ZFS Storage

## System Status

**Host**: i9-zfs-pop.local  
**ZFS Pool**: tank3 (62TB available, 6.2TB free)  
**Virtualization**: KVM/QEMU + libvirt (already installed)  

## Setup Complete

✅ Virtualization tools installed (qemu-kvm, libvirt)  
✅ ZFS pool available with 6.2TB free space  
✅ Ready to create VMs on ZFS storage  

## VM Configuration Plan

### Storage on ZFS
All VMs will be stored on tank3 ZFS pool:
- Location: `/tank3/vms/`
- ISOs: `/tank3/vms/isos/`
- Disks: `/tank3/vms/*.qcow2`

### VMs to Create

1. **FreeBSD 14.3** - Native ZFS, 20GB disk
2. **TrueNAS SCALE** - OpenZFS 2.2, 20GB disk
3. **TrueNAS CORE** - Native ZFS, 20GB disk
4. **OpenBSD 7.6** - OpenZFS (ports), 20GB disk
5. **NetBSD 10.0** - ZFS (pkgsrc), 20GB disk
6. **OpenIndiana** - Native ZFS (Illumos), 20GB disk

**Total**: ~120GB for all VMs (plenty of space on 6.2TB free)

## Next Steps

### Manual Setup (Recommended)

1. **SSH to server**:
   ```bash
   ssh studio@i9-zfs-pop.local
   ```

2. **Create VM directory**:
   ```bash
   sudo mkdir -p /tank3/vms/isos
   sudo chown -R studio:studio /tank3/vms
   ```

3. **Download ISOs**:
   ```bash
   cd /tank3/vms/isos
   
   # FreeBSD
   wget https://download.freebsd.org/releases/ISO-IMAGES/14.3/FreeBSD-14.3-RELEASE-amd64-disc1.iso
   
   # TrueNAS (copy from Mac if already downloaded)
   # OpenBSD
   wget https://cdn.openbsd.org/pub/OpenBSD/7.6/amd64/install76.iso
   
   # NetBSD
   wget https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.0/images/NetBSD-10.0-amd64.iso
   
   # OpenIndiana
   wget https://dlc.openindiana.org/isos/hipster/20231030/OI-hipster-text-20231030.iso
   ```

4. **Create VMs with virt-manager** (GUI):
   ```bash
   virt-manager
   ```
   
   Or use virt-install (CLI):
   ```bash
   # Example: FreeBSD
   virt-install \
     --name freebsd-zfs \
     --memory 4096 \
     --vcpus 2 \
     --disk path=/tank3/vms/freebsd-zfs.qcow2,size=20 \
     --cdrom /tank3/vms/isos/FreeBSD-14.3-RELEASE-amd64-disc1.iso \
     --os-variant freebsd14.0 \
     --network bridge=virbr0 \
     --graphics vnc \
     --noautoconsole
   ```

5. **Access VMs**:
   - Via VNC: Connect to i9-zfs-pop.local:5900+ (port per VM)
   - Via SSH: After installation, configure port forwarding

6. **Test zedlets on each VM**:
   ```bash
   # Copy zedlets
   scp *.sh root@vm-ip:/tmp/
   
   # Install (adjust paths for OS)
   ssh root@vm-ip
   cd /tmp
   # FreeBSD/BSD: /usr/local/etc/zfs/zed.d/
   # TrueNAS SCALE: /etc/zfs/zed.d/
   ```

## Advantages of This Approach

✅ **Real hardware** - x86_64 native, no emulation  
✅ **ZFS storage** - Fast, reliable, snapshots available  
✅ **Plenty of space** - 6.2TB free  
✅ **Better performance** - No ARM64 emulation overhead  
✅ **Production-like** - Same environment as deployment targets  

## Alternative: Use Existing Scrub

The scrub currently running on tank3 will complete in several hours and will test the production deployment. This validates the solution without needing additional VMs.

**Current validation**:
- ✅ Real hardware (i9-zfs-pop)
- ✅ Real ZFS 2.3.0
- ✅ Real 87TB pool
- ✅ Real Datadog API
- ✅ Production Ubuntu-based system

**Recommendation**: Wait for scrub completion to validate production deployment. Additional OS testing can be done later if needed.
