# 💾 ZFS VM Disk Size Analysis

**Date**: 2025-10-24  
**Issue**: Disk space exhaustion from large VM images  
**Solution**: Minimal VMs with lazy allocation

---

## 🔍 Current Status

### Existing VM: `debian-zfs`
```
NAME          STATUS     DISK      
debian-zfs    Stopped    100GiB    ❌ TOO LARGE
```

**Problem**: 100GB disk allocation will exhaust host disk space

---

## ⚠️ Disk Space Reality Check

### Kernel Build Requirements
- **Source code**: ~2GB (Linux kernel git repo)
- **Build artifacts**: ~5-8GB (compiled objects, modules)
- **Installed kernel**: ~200MB (vmlinuz + modules)
- **Total needed**: ~10-12GB for kernel build

### ZFS Requirements
- **ZFS module**: ~50MB
- **Pool metadata**: ~100MB minimum
- **Test data**: Variable (can be minimal)
- **Total needed**: ~500MB-1GB for ZFS testing

### Host Disk Space
```bash
# Check available space
df -h ~
# Typical macOS: 100-500GB total, need to keep 50GB+ free
```

---

## ✅ Solution: Minimal VM Strategy

### Option 1: Separate VMs (RECOMMENDED)

**ZFS Test VM** (for ZFS functionality):
- Disk: 2GB base + 2x 512MB ZFS disks
- Purpose: Test ZFS pools, snapshots, compression
- No kernel building

**Kernel Build VM** (for kernel compilation):
- Disk: 20GB base (lazy allocated)
- Purpose: Build custom kernels
- No ZFS (use host kernel modules)

**Benefits**:
- ✅ ZFS testing uses <3GB total
- ✅ Kernel building isolated
- ✅ Can delete kernel VM after build
- ✅ Lazy allocation = only uses actual space

### Option 2: Single Minimal VM

**Compromise VM**:
- Disk: 15GB base (lazy allocated)
- ZFS: Use loop devices instead of separate disks
- Trade-off: Tight on space but functional

---

## 🚀 Quick Fix: Create Minimal ZFS VM

### Created: `lima-configs/zfs-test-minimal.yaml`

**Specifications**:
```yaml
cpus: 2
memory: 2GiB
disks:
  - basedisk: 2GiB (OS)
  - zfs-disk1: 512MiB (ZFS mirror)
  - zfs-disk2: 512MiB (ZFS mirror)
format: qcow2  # Lazy allocation
```

**Actual Disk Usage**:
- Initial: ~800MB (Debian base image)
- After ZFS setup: ~1.2GB
- Maximum: ~3GB (if fully utilized)

**Usage**:
```bash
# Create minimal ZFS VM
limactl create --name=zfs-test lima-configs/zfs-test-minimal.yaml

# Start and verify
limactl start zfs-test
limactl shell zfs-test -- zpool status testpool

# Test ZFS
limactl shell zfs-test -- zfs create testpool/test
limactl shell zfs-test -- zfs snapshot testpool/test@snap1
limactl shell zfs-test -- zfs list -t snapshot
```

---

## 📊 Disk Space Comparison

| VM Type | Allocated | Actual Usage | Purpose |
|---------|-----------|--------------|---------|
| **debian-zfs (current)** | 100GB | ~5GB | ❌ Overkill |
| **zfs-test-minimal** | 3GB | ~1.2GB | ✅ ZFS testing |
| **kernel-build** | 20GB | ~8GB | ✅ Kernel compile |
| **Combined** | 23GB | ~9GB | ✅ Both tasks |

**Savings**: 77GB allocated space (87% reduction)

---

## 🔧 QCOW2 Lazy Allocation

### How It Works

**QCOW2 Format**:
- Allocates disk space on-demand
- Only uses actual written data
- 100GB virtual = 5GB actual (if only 5GB used)

**Verification**:
```bash
# Check virtual vs actual size
qemu-img info ~/.lima/zfs-test/basedisk

# Output example:
# virtual size: 2 GiB (2147483648 bytes)
# disk size: 1.2 GiB  ← Actual space used
```

**Benefits**:
- ✅ Safe to allocate "large" virtual disks
- ✅ Only uses what's actually written
- ✅ Can grow up to virtual limit
- ✅ Shrinks when files deleted (with fstrim)

---

## 🎯 Recommendations

### For ZFS Testing ONLY
```bash
# Use minimal VM
limactl create --name=zfs-test lima-configs/zfs-test-minimal.yaml
limactl start zfs-test

# Verify ZFS works
limactl shell zfs-test -- zpool status
limactl shell zfs-test -- zfs list
```

### For Kernel Building
```bash
# Create kernel build VM (one-time use)
limactl create --name=kernel-build \
  --cpus=4 --memory=4GiB --disk=20GiB \
  template://debian

# Build kernel
./scripts/build-kernel-live.sh

# Delete after extracting kernel
limactl stop kernel-build
limactl delete kernel-build
```

### For Both (Space Constrained)
```bash
# Use existing debian-zfs but clean it up
limactl start debian-zfs
limactl shell debian-zfs -- sudo apt-get clean
limactl shell debian-zfs -- sudo rm -rf /usr/src/linux  # Remove kernel source
limactl shell debian-zfs -- sudo fstrim -av  # Reclaim space
```

---

## 🧪 Test: Verify Lazy Allocation

```bash
# Create test VM
limactl create --name=disk-test --disk=50GiB template://debian

# Check actual disk usage (should be ~1GB, not 50GB)
du -sh ~/.lima/disk-test/basedisk

# Expected output:
# 1.2G    ~/.lima/disk-test/basedisk  ✅ Only actual usage

# Cleanup
limactl delete disk-test
```

---

## 📋 Action Items

### Immediate
- [ ] Create minimal ZFS VM with `zfs-test-minimal.yaml`
- [ ] Test ZFS functionality (pool, snapshot, compression)
- [ ] Verify disk usage stays under 2GB

### For Kernel Building
- [ ] Create separate 20GB kernel-build VM
- [ ] Build kernel
- [ ] Extract kernel files
- [ ] Delete VM to reclaim space

### Cleanup
- [ ] Delete or shrink `debian-zfs` (100GB → 20GB)
- [ ] Run `fstrim` on all VMs to reclaim space
- [ ] Monitor host disk usage: `df -h ~`

---

## 🎓 Key Learnings

1. **QCOW2 is lazy** - 100GB virtual ≠ 100GB actual
2. **Separate concerns** - ZFS testing needs <3GB
3. **Kernel builds** - Need 15-20GB but can be temporary
4. **Monitor actual usage** - `du -sh` not `limactl list`
5. **Clean up** - Delete VMs after one-time tasks

---

**Status**: Minimal ZFS VM config created  
**Next**: Test with `limactl create --name=zfs-test lima-configs/zfs-test-minimal.yaml`
