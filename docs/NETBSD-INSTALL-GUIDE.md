# NetBSD Installation Guide for Lima VM

## Current Status

NetBSD is booting from ISO - it requires **manual installation** before we can build the custom kernel.

## Installation Steps

### 1. Watch the Boot Progress
```bash
# In another terminal
tail -f ~/.lima/netbsd-arm64/serial.log
```

### 2. Access the VM Console

Once SSH is ready:
```bash
limactl shell netbsd-arm64
```

### 3. Install NetBSD

The installer will prompt you. **Quick install guide**:

1. **Language**: Press Enter for English
2. **Keyboard**: Press Enter for default
3. **Install NetBSD**: Select "Install NetBSD to hard disk"
4. **Available disks**: Choose `ld0` (virtual disk)
5. **Partitioning**: 
   - Choose "Use entire disk"
   - Select "Use default partition sizes"
6. **Bootblocks**: Yes, install bootblocks
7. **Distribution sets**: 
   - Select "Full installation"
   - Or custom: base, etc, comp, kern (minimum needed for kernel build)
8. **Network**: 
   - Configure DHCP on vioif0
   - Yes to autoconfiguration
9. **Installation medium**: CD-ROM
10. **Post-install**:
    - Set root password
    - Add a user (optional)
    - Enable sshd: **YES**
11. **Reboot**: After installation completes

### 4. After Reboot

Stop and restart the VM to boot from disk (not ISO):

```bash
# Stop VM
limactl stop netbsd-arm64

# Edit lima config to boot from disk
# Change boot order or remove ISO

# Restart
limactl start netbsd-arm64
```

### 5. Update System

```bash
limactl shell netbsd-arm64

# Update package database
sudo pkgin update

# Install prerequisites
sudo pkgin -y install git curl bash
```

### 6. Build Custom Kernel

Now you can build the M-series optimized kernel:

```bash
# Copy kernel config
limactl copy kernels/netbsd-m-series-kernel.conf netbsd-arm64:/tmp/
limactl copy kernels/build-netbsd-kernel.sh netbsd-arm64:/tmp/

# Build
limactl shell netbsd-arm64
sudo sh /tmp/build-netbsd-kernel.sh
```

## Why Manual Installation?

NetBSD doesn't provide cloud-init images like Ubuntu/Alpine. The ISO is the official installation method.

**Alternative**: Create a cloud image after first install and reuse it.

## Expected Timeline

- ISO boot: 2-5 minutes
- Manual installation: 10-20 minutes
- Package updates: 5 minutes
- Kernel build: 30-60 minutes

**Total**: ~1-1.5 hours for NetBSD

## Automation Possibility

After first successful install, we can:
1. Export the installed VM as a base image
2. Create a Lima config using that image
3. Future boots skip manual installation

## Quick Reference

```bash
# Watch installation
tail -f ~/.lima/netbsd-arm64/serial.log

# Access console
limactl shell netbsd-arm64

# After install and reboot
limactl stop netbsd-arm64
limactl start netbsd-arm64

# Build kernel
./kernels/build-netbsd-kernel.sh
```

## NetBSD Resources

- [NetBSD Installation Guide](https://www.netbsd.org/docs/guide/en/chap-inst.html)
- [NetBSD ARM64](https://wiki.netbsd.org/ports/evbarm/)
- [pkgsrc](https://www.pkgsrc.org/)
