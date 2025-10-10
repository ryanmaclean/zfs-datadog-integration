# System Verification Results

**Date**: Sat Oct  4 20:07:31 PDT 2025  
**Datadog Site**: datadoghq.com  
**API Key**: Configured (32 characters)  

## Results

- ✅ Datadog API: Valid and reachable

## Lima VMs (Linux Distributions)

- ✅ **zfs-test**: Running
  - ZFS: Available
- ✅ **ubuntu-zfs**: Running
  - ZFS: Available
- ✅ **debian-zfs**: Running
  - ⚠️ ZFS: Not available
- ✅ **rocky-zfs**: Running
  - ⚠️ ZFS: Not available
- ⚠️ **fedora-zfs**: Stopped (can be started)
- ⏳ **arch-zfs**: Not created

## QEMU VMs (BSD/TrueNAS/Illumos)

- ℹ️ No QEMU VMs running

## Available VM Scripts

- 📜 `./qemu-freebsd.sh` - freebsd
- 📜 `./qemu-netbsd.sh` - netbsd
- 📜 `./qemu-openbsd.sh` - openbsd
- 📜 `./qemu-openindiana.sh` - openindiana
- 📜 `./qemu-truenas-core.sh` - truenas-core
- 📜 `./qemu-truenas-scale.sh` - truenas-scale

## Quick Start Commands

```bash
# Start Lima VMs
limactl start --name=ubuntu-zfs lima-zfs.yaml
limactl start --name=debian-zfs lima-debian.yaml

# Start QEMU VMs
./qemu-truenas-scale.sh  # TrueNAS SCALE
./qemu-truenas-core.sh   # TrueNAS CORE
./qemu-freebsd.sh        # FreeBSD
./qemu-openbsd.sh        # OpenBSD
./qemu-netbsd.sh         # NetBSD
./qemu-openindiana.sh    # OpenIndiana

# Test with real Datadog API
VM_NAME=ubuntu-zfs ./comprehensive-validation-test.sh
```
