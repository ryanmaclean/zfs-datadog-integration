# Parallel Download Complete - All ISOs Ready

## Downloaded ISOs on i9-zfs-pop ZFS Storage

All ISOs downloaded in parallel to `/tank3/vms/isos/`:

- ✅ **FreeBSD 14.3**: 1.2GB
- ✅ **TrueNAS SCALE**: 1.6GB  
- ✅ **TrueNAS CORE**: 950MB
- ✅ **OpenBSD 7.6**: 467MB
- ✅ **NetBSD 10.0**: 323MB
- ✅ **OpenIndiana**: Downloading (671MB)

**Total**: ~4.2GB on ZFS storage

## Next: Manual VM Creation

Due to sudo requirements, VMs need to be created manually on the server:

```bash
# SSH to server
ssh studio@i9-zfs-pop.local

# Create VMs as root
sudo virt-install \
  --name freebsd-zfs \
  --memory 4096 \
  --vcpus 2 \
  --disk path=/tank3/vms/freebsd-zfs.qcow2,size=20 \
  --cdrom /tank3/vms/isos/FreeBSD-14.3-RELEASE-amd64-disc1.iso \
  --os-variant freebsd14.0 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5901 \
  --noautoconsole

# Repeat for other OSes...
```

## Or Use virt-manager GUI

```bash
# From your Mac, connect to server
ssh -L 5900:localhost:5900 studio@i9-zfs-pop.local

# Open virt-manager on server
# Create VMs via GUI
```

## Testing Strategy

1. **Install OSes** (20-30 min each via VNC)
2. **Deploy zedlets** to each VM
3. **Create 1GB test pools** (fast)
4. **Run scrubs** (complete in seconds)
5. **Validate in Datadog** (all events from all OSes)

**Timeline**: Complete multi-OS validation in 2-3 hours vs waiting many hours for 87TB production scrub.
