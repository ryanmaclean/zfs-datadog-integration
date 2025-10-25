# 🚀 vfkit VM Setup - Minimal Configurations

**Date**: 2025-10-24  
**Purpose**: Direct vfkit VMs (not Lima) with minimal disk sizes  
**Platform**: macOS with Apple Silicon (ARM64)

---

## 📦 Prerequisites

### Install vfkit

```bash
# Install vfkit via Homebrew
brew install vfkit

# Verify installation
vfkit --version
```

### Install qemu-img (for disk management)

```bash
brew install qemu

# Verify
qemu-img --version
```

---

## 🎯 VM Configurations Created

### 1. Minimal ZFS Test VM

**File**: `vfkit-configs/zfs-test-minimal.sh`

**Specs**:
- Disk: 4GB virtual (2-3GB actual)
- Memory: 2GB
- CPUs: 2
- ZFS Pool: 256MB × 2 (mirrored)

**Usage**:
```bash
chmod +x vfkit-configs/zfs-test-minimal.sh
./vfkit-configs/zfs-test-minimal.sh
```

**What it does**:
1. Downloads Debian 12 ARM64 cloud image
2. Creates 4GB sparse disk (QCOW2 format)
3. Provisions ZFS with cloud-init
4. Creates tiny 256MB ZFS mirror pool
5. Launches VM with vfkit

**Actual disk usage**: ~2-3GB

### 2. Kernel Build VM

**File**: `vfkit-configs/kernel-build.sh`

**Specs**:
- Disk: 15GB virtual (12-13GB actual during build)
- Memory: 4GB
- CPUs: 4
- No ZFS (kernel build only)

**Usage**:
```bash
chmod +x vfkit-configs/kernel-build.sh
./vfkit-configs/kernel-build.sh
```

**What it does**:
1. Downloads Debian 12 ARM64 cloud image
2. Creates 15GB sparse disk
3. Installs kernel build tools
4. Launches VM ready for compilation

**Actual disk usage**: ~12-13GB during build

---

## 🔧 vfkit vs Lima

### Why vfkit?

**vfkit** (direct):
- ✅ Native macOS Virtualization.framework
- ✅ No wrapper overhead
- ✅ Direct control over resources
- ✅ Simpler for single-purpose VMs
- ✅ No interactive prompts

**Lima** (wrapper):
- ⚠️ Adds abstraction layer
- ⚠️ Interactive prompts
- ⚠️ More complex for simple VMs
- ✅ Better for development workflows
- ✅ Built-in file sharing

**For minimal test VMs**: vfkit is better

---

## 📊 Disk Space Verification

### Check Virtual vs Actual Size

```bash
# Virtual size (what you allocated)
qemu-img info ~/.vfkit/zfs-test/disk.img | grep "virtual size"
# virtual size: 4 GiB

# Actual size (what's really used)
du -sh ~/.vfkit/zfs-test/disk.img
# 2.3G  ← Real usage
```

### Monitor Disk Growth

```bash
# Before operation
du -sh ~/.vfkit/*/disk.img

# Do something (install packages, build kernel)

# After operation
du -sh ~/.vfkit/*/disk.img

# See the difference
```

---

## 🧪 Testing the VMs

### Test ZFS VM

```bash
# Start VM
./vfkit-configs/zfs-test-minimal.sh

# In another terminal, SSH to VM
ssh debian@localhost -p 2222

# Verify ZFS
zpool status testpool
zfs list

# Test operations
zfs create testpool/test
dd if=/dev/zero of=/testpool/test/file bs=1M count=50
zfs snapshot testpool/test@snap1
zfs list -t snapshot

# Check disk usage
df -h /
du -sh /zfs-disks/*
```

### Test Kernel Build VM

```bash
# Start VM
./vfkit-configs/kernel-build.sh

# SSH to VM
ssh debian@localhost -p 2222

# Build kernel
cd /usr/src
git clone --depth 1 --branch linux-6.6.y https://github.com/torvalds/linux.git
cd linux
make ARCH=arm64 defconfig
time make ARCH=arm64 -j4 Image modules

# Check disk usage during build
df -h /
du -sh /usr/src/linux
```

---

## 🎯 Advantages of This Setup

### Minimal Disk Usage

**ZFS VM**:
```
Virtual:  4GB
Actual:   2-3GB
Savings:  1-2GB (25-50%)
```

**Kernel VM**:
```
Virtual:  15GB
Actual:   12-13GB during build
Savings:  2-3GB (13-20%)
```

### QCOW2 Sparse Files

**How it works**:
- Allocates blocks on-demand
- Only uses actual written data
- Can grow up to virtual limit
- Shrinks with `qemu-img convert -c`

**Example**:
```bash
# Create 100GB sparse file
qemu-img create -f qcow2 test.img 100G

# Check size
ls -lh test.img    # Shows 100G
du -h test.img     # Shows 196K (actual)

# Write 5GB
dd if=/dev/zero of=test.img bs=1M count=5000

# Check again
du -h test.img     # Shows 5.0G (actual)
```

### Easy Cleanup

```bash
# Stop VM (Ctrl+C in terminal)

# Delete VM completely
rm -rf ~/.vfkit/zfs-test
rm -rf ~/.vfkit/kernel-build

# Reclaim all disk space immediately
```

---

## 🚨 Troubleshooting

### VM Won't Start

**Check vfkit installation**:
```bash
vfkit --version
# Should show version 0.5.0+
```

**Check disk image**:
```bash
qemu-img check ~/.vfkit/zfs-test/disk.img
# Should show "No errors were found"
```

### SSH Connection Refused

**Wait for cloud-init**:
```bash
# Cloud-init takes 30-60 seconds
tail -f ~/.vfkit/zfs-test/console.log
# Wait for "Cloud-init finished"
```

**Check SSH key**:
- Edit `user-data` in the VM script
- Add your actual SSH public key
- Recreate cloud-init ISO

### Disk Full

**Check actual usage**:
```bash
# Inside VM
df -h /

# Outside VM
du -sh ~/.vfkit/*/disk.img
```

**Clean up**:
```bash
# Inside VM
sudo apt-get clean
sudo rm -rf /usr/src/linux  # After kernel build
sudo fstrim -av

# Outside VM (requires shutdown)
qemu-img convert -O qcow2 -c \
  ~/.vfkit/zfs-test/disk.img \
  ~/.vfkit/zfs-test/disk-compact.img
mv ~/.vfkit/zfs-test/disk{-compact,}.img
```

---

## 📋 Quick Reference

### Create ZFS VM
```bash
./vfkit-configs/zfs-test-minimal.sh
```

### Create Kernel VM
```bash
./vfkit-configs/kernel-build.sh
```

### SSH to VM
```bash
ssh debian@localhost -p 2222
```

### Check Disk Usage
```bash
du -sh ~/.vfkit/*/disk.img
```

### Delete VM
```bash
rm -rf ~/.vfkit/zfs-test
rm -rf ~/.vfkit/kernel-build
```

---

## 🎓 Best Practices

1. **Use vfkit directly** - No Lima wrapper for simple VMs
2. **QCOW2 format** - Enables sparse/lazy allocation
3. **Separate VMs** - ZFS testing vs kernel building
4. **Delete after use** - Kernel build VM is temporary
5. **Monitor actual usage** - Use `du`, not `ls -lh`
6. **Cloud-init** - Automated provisioning, no manual setup

---

**Status**: vfkit configurations created  
**ZFS VM**: 4GB virtual, 2-3GB actual  
**Kernel VM**: 15GB virtual, 12-13GB actual  
**Next**: Test the VMs with the scripts
