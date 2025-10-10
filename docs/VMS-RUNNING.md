# VMs Running on i9-zfs-pop

## Status

✅ **Passwordless sudo configured**  
✅ **FreeBSD VM running**  
🔄 **TrueNAS VMs starting**  

## Access

**VNC Ports:**
- FreeBSD: `i9-zfs-pop.local:5901`
- TrueNAS SCALE: `i9-zfs-pop.local:5902`
- TrueNAS CORE: `i9-zfs-pop.local:5903`

## Next Steps

1. **Complete installations via VNC** (20-30 min each)
2. **Configure SSH access** on each VM
3. **Run parallel test**: `./parallel-vm-test.sh`

This will:
- Deploy zedlets to all VMs simultaneously
- Create 1GB test pools
- Run scrubs in parallel (complete in seconds)
- Validate events in Datadog from all OSes

**Timeline**: Complete multi-OS validation in ~1 hour
