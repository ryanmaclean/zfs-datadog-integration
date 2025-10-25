# 🎯 Minimal VM Strategy - Worst Case Scenario

**Philosophy**: Absolute minimum virtual disk sizes that actually work  
**Goal**: Prevent disk space exhaustion even in worst case  
**Date**: 2025-10-24

---

## 🔬 Worst-Case Disk Requirements

### ZFS Testing Only

**Absolute Minimum**:
```
Base OS (Ubuntu minimal):     1.5GB
ZFS packages (zfsutils):      200MB
ZFS pool (256MB × 2 mirror):  512MB
Headroom (operations):        800MB
─────────────────────────────────
TOTAL:                        3.0GB
SAFE ALLOCATION:              4GB virtual
```

**Actual Usage**: ~2-3GB (with lazy allocation)

### Kernel Building Only

**Absolute Minimum**:
```
Base OS (Ubuntu minimal):     1.5GB
Build tools (gcc, make):      500MB
Kernel source (git clone):    2.0GB
Build artifacts (objects):    6.0GB
Installed kernel:             200MB
Headroom (tmp, cache):        1.8GB
─────────────────────────────────
TOTAL:                        12.0GB
SAFE ALLOCATION:              15GB virtual
```

**Actual Usage**: ~12-13GB during build, ~8GB after cleanup

### Combined (NOT Recommended)

**If you must**:
```
Base OS:                      1.5GB
ZFS packages:                 200MB
Build tools:                  500MB
Kernel source:                2.0GB
Build artifacts:              6.0GB
ZFS pool (minimal):           512MB
Headroom:                     2.3GB
─────────────────────────────────
TOTAL:                        13.0GB
SAFE ALLOCATION:              16GB virtual
```

**Better**: Use separate VMs

---

## ✅ Recommended VM Configurations

### Configuration 1: Separate VMs (BEST)

**ZFS Test VM** (`zfs-test-minimal.yaml`):
```yaml
disk: "4GiB"      # Virtual size
memory: "2GiB"
cpus: 2

# ZFS pool: 256MB × 2 = 512MB total
# Actual usage: ~2-3GB
```

**Kernel Build VM** (`zfs-kernel-build.yaml`):
```yaml
disk: "15GiB"     # Virtual size
memory: "4GiB"
cpus: 4

# No ZFS, only kernel build
# Actual usage: ~12-13GB during build
# DELETE after extracting kernel
```

**Total Disk Usage**:
- ZFS VM: ~3GB (persistent)
- Kernel VM: ~13GB (temporary, delete after)
- **Peak**: ~16GB
- **Steady state**: ~3GB (after deleting kernel VM)

### Configuration 2: Single Minimal VM (Tight)

**Combined VM** (if space constrained):
```yaml
disk: "16GiB"     # Virtual size
memory: "4GiB"
cpus: 4

# Both ZFS and kernel build
# Actual usage: ~13-15GB
# Must clean up kernel source after build
```

**Cleanup Required**:
```bash
# After kernel build
sudo rm -rf /usr/src/linux      # Frees ~8GB
sudo apt-get clean              # Frees ~200MB
sudo fstrim -av                 # Reclaim space
# Final usage: ~5-6GB
```

---

## 📊 Size Comparison

| VM Type | Virtual | Actual (Peak) | Actual (Steady) | Purpose |
|---------|---------|---------------|-----------------|---------|
| **ZFS Only** | 4GB | 2-3GB | 2-3GB | ✅ Testing ZFS |
| **Kernel Only** | 15GB | 12-13GB | N/A (delete) | ✅ Build kernel |
| **Combined** | 16GB | 13-15GB | 5-6GB | ⚠️ Tight on space |
| **Old debian-zfs** | 100GB | 3-4GB | 3-4GB | ❌ Wasteful virtual size |

---

## 🎯 ZFS Pool Sizing

### Minimal Test Pool (256MB usable)

**Configuration**:
```bash
# Two 256MB sparse files in mirror
truncate -s 256M /zfs-disks/disk1.img
truncate -s 256M /zfs-disks/disk2.img
zpool create testpool mirror disk1.img disk2.img
zfs set quota=200M testpool  # Hard limit
```

**What you can test**:
- ✅ Pool creation/destruction
- ✅ Snapshots (10-20 snapshots)
- ✅ Compression (lz4)
- ✅ Basic I/O
- ❌ Large datasets (limited to 200MB)
- ❌ Performance testing (too small)

### Small Test Pool (1GB usable)

**Configuration**:
```bash
# Two 1GB sparse files in mirror
truncate -s 1G /zfs-disks/disk1.img
truncate -s 1G /zfs-disks/disk2.img
zpool create testpool mirror disk1.img disk2.img
```

**Requires**: 6GB virtual disk instead of 4GB  
**What you can test**: Everything above + moderate datasets

---

## 🚨 Worst-Case Scenarios

### Scenario 1: Host has only 20GB free

**Strategy**: Separate VMs, delete kernel VM after use
```
ZFS VM:     4GB virtual → 3GB actual     ✅
Kernel VM: 15GB virtual → 13GB actual    ✅
Total:     19GB virtual → 16GB actual    ✅ Fits!
```

**After kernel build**:
```
Delete kernel VM → Frees 13GB
ZFS VM only:       3GB actual            ✅ Only 3GB used
```

### Scenario 2: Host has only 10GB free

**Strategy**: Ultra-minimal single VM
```
Combined VM: 10GB virtual → 8-9GB actual ⚠️ Very tight
```

**Must do**:
- Use 2GB ZFS pool (not 256MB)
- Delete kernel source immediately after build
- Run `apt-get clean` after every install
- Use `fstrim` regularly

**Not recommended** - too risky

### Scenario 3: Host has 50GB+ free

**Strategy**: Use recommended separate VMs
```
ZFS VM:     4GB virtual → 3GB actual
Kernel VM: 15GB virtual → 13GB actual
Total:     19GB actual                   ✅ Plenty of room
```

---

## 🔧 Disk Space Monitoring

### Check Before Creating VM

```bash
# Check available space
df -h ~

# Need at least:
# - 20GB for separate VMs
# - 10GB for single VM (tight)
# - 5GB for ZFS-only VM
```

### Monitor During Operations

```bash
# Check actual VM disk usage
du -sh ~/.lima/*/diffdisk

# Check VM internal usage
limactl shell <vm> -- df -h /

# Watch disk growth in real-time
watch -n 5 'du -sh ~/.lima/*/diffdisk'
```

### Cleanup Commands

```bash
# Inside VM
sudo apt-get clean                    # Clear package cache
sudo rm -rf /usr/src/linux           # Remove kernel source
sudo rm -rf /var/log/*.log           # Clear old logs
sudo fstrim -av                      # Reclaim deleted space

# Outside VM (requires shutdown)
limactl stop <vm>
qemu-img convert -O qcow2 -c \
  ~/.lima/<vm>/diffdisk \
  ~/.lima/<vm>/diffdisk-compact
mv ~/.lima/<vm>/diffdisk{-compact,}
```

---

## 📋 Quick Reference

### Create Minimal ZFS VM
```bash
limactl create --name=zfs-test lima-configs/zfs-test-minimal.yaml
limactl start zfs-test
# Actual usage: ~2-3GB
```

### Create Kernel Build VM
```bash
limactl create --name=kernel-build lima-configs/zfs-kernel-build.yaml
limactl start kernel-build
# Actual usage: ~12-13GB during build
```

### Build Kernel & Cleanup
```bash
# Build kernel
./scripts/build-kernel-live.sh

# Extract kernel
limactl shell kernel-build -- tar czf /tmp/kernel.tar.gz /boot/vmlinuz* /lib/modules/*
limactl copy kernel-build:/tmp/kernel.tar.gz ./

# DELETE VM to reclaim 13GB
limactl stop kernel-build
limactl delete kernel-build
```

### Check Disk Usage
```bash
# Virtual size (ignore this)
limactl list

# Actual usage (this matters)
du -sh ~/.lima/*/diffdisk
```

---

## 🎓 Key Principles

1. **Virtual ≠ Actual**: 100GB virtual can use only 3GB actual (sparse files)
2. **Separate concerns**: ZFS testing needs 4GB, kernel building needs 15GB
3. **Delete temporary VMs**: Kernel build VM should be deleted after use
4. **Monitor actual usage**: Use `du`, not `limactl list`
5. **Worst-case planning**: Always assume full disk usage for safety
6. **Lazy allocation**: QCOW2 only uses what's written, not what's allocated

---

## ✅ Final Recommendations

**For ZFS testing only**:
- Use `zfs-test-minimal.yaml` (4GB virtual, 3GB actual)
- Tiny 256MB ZFS pool for basic testing
- Safe for hosts with 10GB+ free space

**For kernel building**:
- Use `zfs-kernel-build.yaml` (15GB virtual, 13GB actual)
- Delete VM after extracting kernel
- Needs 20GB+ free space during build

**For both**:
- Use separate VMs (total 19GB peak, 3GB steady)
- Or use single 16GB VM with aggressive cleanup
- Needs 25GB+ free space to be safe

---

**Status**: Minimal VM configs created  
**ZFS VM**: 4GB virtual (2-3GB actual)  
**Kernel VM**: 15GB virtual (12-13GB actual)  
**Strategy**: Separate VMs, delete kernel VM after use
