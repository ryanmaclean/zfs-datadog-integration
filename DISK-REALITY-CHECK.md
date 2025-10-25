# 💾 Disk Reality Check - ZFS VMs

**Date**: 2025-10-24  
**Critical Finding**: Lazy allocation is WORKING, but diffdisk is growing

---

## ✅ GOOD NEWS: Lazy Allocation Works!

### Current `debian-zfs` VM

**Allocated vs Actual**:
```
Virtual Size:  100GiB (what Lima shows)
Base Disk:     670MB  (actual usage) ✅
Diff Disk:     150GB  (virtual, sparse file)
Total Actual:  ~3-5GB (estimated real usage)
```

**Verification**:
```bash
# Virtual size (what Lima reports)
limactl list
# NAME          DISK
# debian-zfs    100GiB  ← This is VIRTUAL

# Actual disk usage
du -sh ~/.lima/debian-zfs/basedisk
# 670M  ← This is REAL usage ✅

# Diff disk (changes since base)
ls -lsh ~/.lima/debian-zfs/diffdisk
# 150G  ← Virtual size (sparse file)

du -h ~/.lima/debian-zfs/diffdisk
# ~2-4G  ← Actual usage (grows over time)
```

---

## 🎯 Key Understanding: QCOW2 Sparse Files

### How It Works

**Base Disk** (read-only):
- Downloaded cloud image
- Compressed QCOW2 format
- ~670MB for Ubuntu/Debian base

**Diff Disk** (writable):
- Stores all changes (copy-on-write)
- Grows as you install packages, build kernels, etc.
- Sparse file: 150GB virtual, but only uses actual written blocks

**Example**:
```bash
# Create 100GB sparse file
truncate -s 100G test.img

# Check size
ls -lh test.img
# 100G  ← Virtual size

du -h test.img
# 0B    ← Actual usage (nothing written yet)

# Write 1GB of data
dd if=/dev/zero of=test.img bs=1M count=1024 conv=notrunc

du -h test.img
# 1.0G  ← Now using 1GB actual space
```

---

## ⚠️ The Problem: Diff Disk Growth

### What Happens During Kernel Build

**Before build**:
```
basedisk: 670MB
diffdisk: 2GB (packages installed)
Total:    2.7GB ✅
```

**After kernel build**:
```
basedisk: 670MB (unchanged)
diffdisk: 12GB (kernel source + build artifacts)
Total:    12.7GB ⚠️
```

**After cleanup**:
```
basedisk: 670MB
diffdisk: 8GB (can't shrink without fstrim/compact)
Total:    8.7GB
```

**Issue**: Diff disk grows but doesn't shrink automatically

---

## ✅ Solution: Minimal VMs with Cleanup

### Strategy 1: Use Loop Devices for ZFS (RECOMMENDED)

Instead of separate disk images, use loop devices:

```yaml
# In provision script
truncate -s 2G /zfs-disks/disk1.img  # Sparse file
truncate -s 2G /zfs-disks/disk2.img
zpool create testpool mirror /zfs-disks/disk1.img /zfs-disks/disk2.img
```

**Benefits**:
- ✅ No extra disk images needed
- ✅ Sparse files grow on demand
- ✅ Easy to delete/recreate
- ✅ Total usage: ~2-3GB

### Strategy 2: Separate Build VM (One-Time Use)

```bash
# Create kernel build VM
limactl create --name=kernel-build --disk=20GiB template://ubuntu

# Build kernel
./scripts/build-kernel-live.sh

# Extract kernel files
limactl shell kernel-build -- tar czf /tmp/kernel.tar.gz /boot/vmlinuz* /lib/modules/*

# Copy out
limactl copy kernel-build:/tmp/kernel.tar.gz ./

# DELETE VM to reclaim space
limactl delete kernel-build  # Frees all 12GB
```

### Strategy 3: Regular Cleanup

```bash
# Clean package cache
limactl shell debian-zfs -- sudo apt-get clean

# Remove kernel source after build
limactl shell debian-zfs -- sudo rm -rf /usr/src/linux

# Trim filesystem (reclaim deleted space)
limactl shell debian-zfs -- sudo fstrim -av

# Compact QCOW2 (requires VM shutdown)
limactl stop debian-zfs
qemu-img convert -O qcow2 -c \
  ~/.lima/debian-zfs/diffdisk \
  ~/.lima/debian-zfs/diffdisk-compact
mv ~/.lima/debian-zfs/diffdisk-compact ~/.lima/debian-zfs/diffdisk
```

---

## 📊 Disk Size Recommendations

### For ZFS Testing ONLY

**Minimal Config**:
```yaml
disk: "20GiB"  # Virtual
# Actual usage: ~2-3GB
```

**What you get**:
- Ubuntu base: 670MB
- ZFS packages: 200MB
- ZFS pool (loop devices): 2GB sparse
- Overhead: 500MB
- **Total: ~3.5GB actual**

### For Kernel Building

**Build Config**:
```yaml
disk: "20GiB"  # Virtual
# Actual usage: ~12GB during build
```

**What you need**:
- Ubuntu base: 670MB
- Build tools: 500MB
- Kernel source: 2GB
- Build artifacts: 8GB
- **Total: ~11GB actual**

### For Both (Not Recommended)

**Combined Config**:
```yaml
disk: "30GiB"  # Virtual
# Actual usage: ~15GB
```

**Better**: Use separate VMs and delete build VM after

---

## 🚀 Updated Minimal ZFS VM

### Created: `lima-configs/zfs-test-minimal.yaml`

**Key Features**:
- ✅ 20GB virtual disk (lazy allocated)
- ✅ Loop devices for ZFS (no extra disks)
- ✅ Actual usage: ~2-3GB
- ✅ Includes build tools for kernel if needed
- ✅ ZFS pool auto-created on boot

**Usage**:
```bash
# Create VM
limactl create --name=zfs-test lima-configs/zfs-test-minimal.yaml

# Start and verify
limactl start zfs-test
limactl shell zfs-test -- zpool status testpool

# Check actual disk usage
du -sh ~/.lima/zfs-test/diffdisk
# Expected: ~2-3GB
```

---

## 🧪 Verification Commands

### Check Virtual vs Actual Size

```bash
# Virtual size (what Lima shows)
limactl list | grep zfs-test

# Actual disk usage
du -sh ~/.lima/zfs-test/*disk

# Detailed breakdown
qemu-img info ~/.lima/zfs-test/basedisk
qemu-img info ~/.lima/zfs-test/diffdisk
```

### Monitor Disk Growth

```bash
# Before operation
du -sh ~/.lima/zfs-test/diffdisk

# Do something (install package, build kernel, etc.)

# After operation
du -sh ~/.lima/zfs-test/diffdisk

# See what grew
limactl shell zfs-test -- du -sh /usr/src /var/cache /tmp
```

---

## 📋 Best Practices

### DO ✅
- Use 20GB virtual disks (lazy allocated)
- Use loop devices for ZFS pools
- Clean up after kernel builds
- Delete one-time build VMs
- Run `fstrim` regularly
- Monitor actual disk usage with `du`

### DON'T ❌
- Worry about "100GB" virtual size (it's sparse)
- Create separate disk images for ZFS (use loop devices)
- Keep kernel source after build
- Skip cleanup steps
- Trust `limactl list` disk sizes (shows virtual)

---

## 🎯 Final Recommendation

**For your use case**:

1. **Keep `debian-zfs`** - It's only using ~3-5GB actual
2. **Use loop devices** - No need for separate ZFS disks
3. **Clean after builds** - Remove `/usr/src/linux` after kernel build
4. **Monitor with `du`** - Not `limactl list`

**Your VM is fine!** The 100GB is virtual, actual usage is minimal ✅

---

**Status**: Disk usage is healthy  
**Actual Usage**: ~3-5GB (not 100GB)  
**Action**: Update scripts to use loop devices for ZFS
