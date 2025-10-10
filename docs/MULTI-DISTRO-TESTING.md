# Multi-Distribution Testing Guide

## Available Lima VM Configurations

All configurations use **ARM64 native images** for Apple Silicon Macs.

### 1. Ubuntu 24.04 ✅ (Already Tested)
**File**: `lima-zfs.yaml`
```bash
limactl start --name=ubuntu-zfs lima-zfs.yaml
```
- **Status**: Fully tested and working
- **OpenZFS**: 2.2.2 from Ubuntu repos
- **Image**: Official Ubuntu cloud image

### 2. Debian 12 (Bookworm) 🆕
**File**: `lima-debian.yaml`
```bash
limactl start --name=debian-zfs lima-debian.yaml
```
- **Image**: https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2
- **OpenZFS**: From Debian repos
- **Package**: zfsutils-linux, zfs-dkms

### 3. Rocky Linux 9 🆕
**File**: `lima-rocky.yaml`
```bash
limactl start --name=rocky-zfs lima-rocky.yaml
```
- **Image**: https://dl.rockylinux.org/pub/rocky/9/images/aarch64/Rocky-9-GenericCloud-Base.latest.aarch64.qcow2
- **OpenZFS**: From ZFS on Linux repos
- **Package**: zfs (from zfsonlinux.org)

### 4. Fedora 40 🆕
**File**: `lima-fedora.yaml`
```bash
limactl start --name=fedora-zfs lima-fedora.yaml
```
- **Image**: https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/aarch64/images/Fedora-Cloud-Base-Generic.aarch64-40-1.14.qcow2
- **OpenZFS**: From ZFS on Linux repos
- **Package**: zfs (from zfsonlinux.org)

### 5. Arch Linux 🆕
**File**: `lima-arch.yaml`
```bash
limactl start --name=arch-zfs lima-arch.yaml
```
- **Image**: https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-aarch64-cloudimg.qcow2
- **OpenZFS**: From archzfs repo
- **Package**: zfs-linux

### 6. FreeBSD ⚠️ (Limited Support)
**File**: `lima-freebsd.yaml`
```bash
# Note: Lima has limited FreeBSD support
# This is a placeholder configuration
```
- **Status**: Lima doesn't fully support FreeBSD VMs yet
- **Alternative**: Use VirtualBox, VMware, or native FreeBSD
- **Scripts**: POSIX-compatible and ready for FreeBSD

### 7. TrueNAS SCALE ℹ️
**Note**: TrueNAS SCALE is Debian-based
```bash
# Use Debian configuration as base
# TrueNAS SCALE doesn't provide cloud images
# Test on actual TrueNAS hardware/VM
```
- **Base**: Debian 11/12
- **Scripts**: Should work with Debian config
- **Testing**: Requires actual TrueNAS installation

## Automated Multi-Distro Testing

### Run All Tests
```bash
./all-distros-test.sh
```

This will:
1. Start each VM sequentially
2. Install OpenZFS
3. Copy and install zedlets
4. Create test pool
5. Trigger scrub event
6. Verify events captured
7. Generate summary report

### Run Single Distro Test
```bash
# Test Debian only
limactl start --name=debian-zfs lima-debian.yaml
./comprehensive-validation-test.sh  # Modify VM_NAME="debian-zfs"
```

### Keep VMs Running
```bash
KEEP_VMS=true ./all-distros-test.sh
```

## Image Sources

### Official Cloud Images (ARM64)
- **Ubuntu**: https://cloud-images.ubuntu.com/
- **Debian**: https://cloud.debian.org/images/cloud/
- **Rocky Linux**: https://dl.rockylinux.org/pub/rocky/
- **Fedora**: https://download.fedoraproject.org/pub/fedora/
- **Arch Linux**: https://geo.mirror.pkgbuild.com/images/

### AMD64 Images (Emulated)
All distributions also provide AMD64 images. Lima can emulate x86_64 on ARM64:

```yaml
arch: "x86_64"  # Will use QEMU emulation
images:
  - location: "https://cloud-images.ubuntu.com/.../amd64.img"
    arch: "x86_64"
```

**Note**: Emulation is slower (~10x) but works for testing.

## OpenZFS Installation Methods

### Debian/Ubuntu
```bash
apt-get install zfsutils-linux zfs-dkms
```

### RHEL/Rocky/Fedora
```bash
dnf install https://zfsonlinux.org/epel/zfs-release-2-3.el9.noarch.rpm
dnf install zfs
```

### Arch Linux
```bash
# Add archzfs repo to /etc/pacman.conf
pacman -S zfs-linux
```

### FreeBSD
```bash
# ZFS is built-in, no installation needed
```

## Testing Matrix

| Distribution | ARM64 | AMD64 | OpenZFS | Status |
|--------------|-------|-------|---------|--------|
| Ubuntu 24.04 | ✅ Native | ✅ Emulated | 2.2.2 | ✅ Tested |
| Debian 12 | ✅ Native | ✅ Emulated | 2.1.x | 🆕 Ready |
| Rocky 9 | ✅ Native | ✅ Emulated | 2.2.x | 🆕 Ready |
| Fedora 40 | ✅ Native | ✅ Emulated | 2.2.x | 🆕 Ready |
| Arch Linux | ✅ Native | ✅ Emulated | Latest | 🆕 Ready |
| FreeBSD 14 | ⚠️ Limited | ⚠️ Limited | Native | ⚠️ Manual |
| TrueNAS SCALE | N/A | N/A | 2.1.x | ℹ️ Manual |

## Quick Start

### Test on Debian
```bash
# Start VM
limactl start --name=debian-zfs lima-debian.yaml

# Wait for startup
sleep 30

# Verify ZFS
limactl shell debian-zfs sudo zfs version

# Run comprehensive tests
VM_NAME=debian-zfs ./comprehensive-validation-test.sh
```

### Test on Rocky Linux
```bash
# Start VM
limactl start --name=rocky-zfs lima-rocky.yaml

# Wait for startup (Rocky takes longer)
sleep 60

# Verify ZFS
limactl shell rocky-zfs sudo zfs version

# Run tests
VM_NAME=rocky-zfs ./comprehensive-validation-test.sh
```

## Troubleshooting

### VM Won't Start
```bash
# Check Lima logs
limactl list
cat ~/.lima/<vm-name>/serial*.log

# Try with more memory
# Edit YAML: memory: "8GiB"
```

### OpenZFS Won't Install
```bash
# Check kernel headers
limactl shell <vm-name> uname -r
limactl shell <vm-name> ls /lib/modules/$(uname -r)

# Reinstall headers
# Debian/Ubuntu: apt-get install linux-headers-$(uname -r)
# Rocky/Fedora: dnf install kernel-devel
```

### ZFS Module Won't Load
```bash
# Check dmesg
limactl shell <vm-name> sudo dmesg | grep -i zfs

# Try manual load
limactl shell <vm-name> sudo modprobe zfs

# Check module
limactl shell <vm-name> lsmod | grep zfs
```

## Performance Notes

### Native ARM64
- **Speed**: Full native performance
- **Recommended**: Use ARM64 images when available
- **Startup**: 30-60 seconds

### Emulated AMD64
- **Speed**: ~10x slower
- **Use Case**: Testing only, not for production
- **Startup**: 2-5 minutes

## Cleanup

### Remove Single VM
```bash
limactl stop debian-zfs
limactl delete debian-zfs
```

### Remove All Test VMs
```bash
for vm in ubuntu-zfs debian-zfs rocky-zfs fedora-zfs arch-zfs; do
    limactl stop $vm 2>/dev/null || true
    limactl delete $vm 2>/dev/null || true
done
```

## Next Steps

1. **Run automated tests**: `./all-distros-test.sh`
2. **Test individual distros**: Start VM and run comprehensive tests
3. **Test on real hardware**: Deploy on actual servers
4. **Test TrueNAS**: Use actual TrueNAS installation

## Resources

- [Lima Documentation](https://lima-vm.io/docs/)
- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [Cloud Images Directory](https://cloud-images.ubuntu.com/)
