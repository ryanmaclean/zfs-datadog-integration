# 🐡 BSD & TrueNAS vfkit Setup

**Date**: 2025-10-24  
**Purpose**: FreeBSD, OpenBSD, and TrueNAS VMs with minimal disk usage  
**Platform**: macOS Apple Silicon (ARM64)

---

## 🎯 VM Configurations Created

### 1. FreeBSD 14.2 ARM64 + Native ZFS

**File**: `vfkit-configs/freebsd-zfs.sh`

**Specs**:
- Disk: 8GB virtual (~4-5GB actual)
- Memory: 4GB
- CPUs: 2
- **ZFS**: Native (built into FreeBSD kernel!)

**Features**:
- ✅ Native ZFS support (no installation needed)
- ✅ Production-stable FreeBSD 14.2
- ✅ Cloud-init automated setup
- ✅ 512MB test ZFS pool auto-created

**Usage**:
```bash
./vfkit-configs/freebsd-zfs.sh
```

**After boot**:
```bash
# ZFS is already configured!
zpool status testpool
zfs list
zfs create testpool/mydata
```

---

### 2. OpenBSD 7.6 ARM64

**File**: `vfkit-configs/openbsd-minimal.sh`

**Specs**:
- Disk: 6GB virtual (~3-4GB actual)
- Memory: 2GB
- CPUs: 2
- **ZFS**: ❌ Not supported (license incompatibility)

**Features**:
- ✅ Latest OpenBSD 7.6
- ✅ Minimal footprint
- ⚠️ Interactive installation required
- ❌ No ZFS (OpenBSD uses FFS/Softraid)

**Usage**:
```bash
./vfkit-configs/openbsd-minimal.sh
# Follow installer prompts
```

**Why no ZFS?**:
- OpenBSD uses BSD license
- ZFS uses CDDL license
- License incompatibility prevents ZFS integration

---

### 3. TrueNAS SCALE (Debian + ZFS)

**File**: `vfkit-configs/truenas-scale.sh`

**Specs**:
- Main disk: 20GB virtual (~8-10GB actual)
- ZFS disks: 2x 4GB (mirror pool)
- Memory: 8GB (TrueNAS minimum)
- CPUs: 4

**Features**:
- ✅ Debian-based TrueNAS
- ✅ Native ZFS
- ✅ Web UI management
- ✅ Enterprise features
- ✅ Better hardware support

**Usage**:
```bash
./vfkit-configs/truenas-scale.sh
# Follow TrueNAS installer
# Access Web UI: http://truenas-ip:80
```

**After installation**:
- Create ZFS pool from 2x 4GB disks (mirror)
- Configure shares, datasets, snapshots via Web UI
- Enable Datadog integration

---

### 4. TrueNAS CORE (FreeBSD + ZFS)

**File**: `vfkit-configs/truenas-core.sh`

**Specs**:
- Main disk: 20GB virtual (~8-10GB actual)
- ZFS disks: 2x 4GB (mirror pool)
- Memory: 8GB (TrueNAS minimum)
- CPUs: 4

**Features**:
- ✅ FreeBSD-based TrueNAS
- ✅ Native ZFS (FreeBSD kernel)
- ✅ Web UI management
- ✅ Rock-solid stability
- ⚠️ Older hardware support

**Usage**:
```bash
./vfkit-configs/truenas-core.sh
# Follow TrueNAS installer
# Access Web UI: http://truenas-ip:80
```

**CORE vs SCALE**:
- **CORE**: FreeBSD-based, more stable, older
- **SCALE**: Debian-based, newer features, better hardware support

---

## 📊 Disk Space Requirements

| VM | Virtual | Actual (Empty) | Actual (Installed) | ZFS Support |
|---|---|---|---|---|
| **FreeBSD** | 8GB | 196K | ~4-5GB | ✅ Native |
| **OpenBSD** | 6GB | 196K | ~3-4GB | ❌ No |
| **TrueNAS SCALE** | 28GB total | 196K | ~12-15GB | ✅ Native |
| **TrueNAS CORE** | 28GB total | 196K | ~12-15GB | ✅ Native |

**Total if running all**: ~35GB actual (with lazy allocation)

---

## 🚀 Quick Start Guide

### Test FreeBSD (Fastest)

```bash
# Start FreeBSD VM
./vfkit-configs/freebsd-zfs.sh

# Wait for boot (~30 seconds)

# ZFS is already configured!
# Test pool 'testpool' is created automatically
```

### Test TrueNAS SCALE (Recommended)

```bash
# Start TrueNAS SCALE
./vfkit-configs/truenas-scale.sh

# Follow installer:
# 1. Install to main disk
# 2. Set admin password
# 3. Reboot

# After boot:
# 1. Access Web UI: http://truenas-ip:80
# 2. Login: admin / <your-password>
# 3. Storage → Create Pool
# 4. Select 2x 4GB disks → Mirror
# 5. Create datasets, shares, etc.
```

### Test OpenBSD (No ZFS)

```bash
# Start OpenBSD VM
./vfkit-configs/openbsd-minimal.sh

# Follow installer prompts
# Note: No ZFS support
```

---

## 🎯 ZFS Comparison

### FreeBSD Native ZFS
```bash
# Built into kernel
zpool create tank mirror /dev/da1 /dev/da2
zfs create tank/data
zfs snapshot tank/data@snap1
zfs send tank/data@snap1 | zfs receive backup/data
```

**Pros**:
- ✅ Native implementation
- ✅ Excellent performance
- ✅ Full feature set
- ✅ Rock solid

**Cons**:
- ⚠️ Manual configuration
- ⚠️ No Web UI (unless TrueNAS)

### TrueNAS ZFS
```
# Web UI management
Storage → Pools → Add
  - Select disks
  - Choose RAID level
  - Create datasets
  - Configure snapshots
  - Set up replication
```

**Pros**:
- ✅ Web UI (easy)
- ✅ Automated snapshots
- ✅ Built-in monitoring
- ✅ Datadog integration ready

**Cons**:
- ⚠️ Larger footprint
- ⚠️ More complex

### OpenBSD
```bash
# No ZFS - use FFS or Softraid
newfs /dev/sd1a
mount /dev/sd1a /mnt
```

**Pros**:
- ✅ Secure by default
- ✅ Clean codebase
- ✅ Minimal

**Cons**:
- ❌ No ZFS (license)
- ⚠️ No advanced storage features

---

## 🧪 Testing Checklist

### FreeBSD ZFS Test
```bash
# Start VM
./vfkit-configs/freebsd-zfs.sh

# Verify ZFS
zpool status testpool
zfs list

# Test operations
zfs create testpool/test
dd if=/dev/zero of=/testpool/test/file bs=1M count=100
zfs snapshot testpool/test@snap1
zfs list -t snapshot

# Check compression
zfs get compression testpool
zfs get compressratio testpool

# Verify
✅ Pool created
✅ Compression working
✅ Snapshots working
```

### TrueNAS SCALE Test
```bash
# Start VM
./vfkit-configs/truenas-scale.sh

# Install TrueNAS
# Access Web UI: http://truenas-ip:80

# Create pool via Web UI
Storage → Create Pool
  Name: tank
  Disks: Select 2x 4GB
  Layout: Mirror
  Create

# Create dataset
Datasets → Add Dataset
  Name: data
  Compression: lz4
  Create

# Test
✅ Pool created via Web UI
✅ Dataset created
✅ Web UI accessible
✅ Monitoring active
```

### OpenBSD Test
```bash
# Start VM
./vfkit-configs/openbsd-minimal.sh

# Install OpenBSD
# Follow prompts

# Test filesystem
df -h
mount

# Verify
✅ OpenBSD installed
✅ FFS filesystem working
❌ No ZFS (expected)
```

---

## 📋 Disk Usage Monitoring

### Check Virtual vs Actual

```bash
# Check all BSD VMs
du -sh ~/.vfkit/freebsd-zfs
du -sh ~/.vfkit/openbsd
du -sh ~/.vfkit/truenas-scale
du -sh ~/.vfkit/truenas-core

# Total usage
du -sh ~/.vfkit
```

### Expected Usage

**After installation**:
```
FreeBSD:       ~4-5GB
OpenBSD:       ~3-4GB
TrueNAS SCALE: ~12-15GB
TrueNAS CORE:  ~12-15GB
Total:         ~35GB (if all running)
```

**With 116GB available**: ✅ Plenty of room!

---

## 🎓 Recommendations

### For ZFS Testing
**Use**: FreeBSD or TrueNAS SCALE
- FreeBSD: Manual, lightweight, native ZFS
- TrueNAS SCALE: Web UI, automated, enterprise features

### For BSD Learning
**Use**: OpenBSD
- Clean, secure, minimal
- No ZFS, but excellent for BSD fundamentals

### For Production ZFS
**Use**: TrueNAS SCALE
- Web UI management
- Automated snapshots
- Built-in monitoring
- Datadog integration ready

---

## 🚨 Important Notes

### TrueNAS Requirements
- **Minimum**: 8GB RAM, 20GB disk
- **Recommended**: 16GB RAM, 50GB disk
- **For production**: 32GB+ RAM, 100GB+ disk

### ZFS Memory Usage
- ZFS uses ~1GB RAM per 1TB storage
- TrueNAS needs 8GB minimum
- FreeBSD can run with 2GB for small pools

### License Compatibility
- **FreeBSD**: ✅ ZFS compatible (CDDL + BSD)
- **OpenBSD**: ❌ ZFS incompatible (license conflict)
- **TrueNAS**: ✅ ZFS compatible (designed for it)

---

## 🎯 Quick Reference

### Start VMs
```bash
# FreeBSD + ZFS
./vfkit-configs/freebsd-zfs.sh

# OpenBSD (no ZFS)
./vfkit-configs/openbsd-minimal.sh

# TrueNAS SCALE (Debian + ZFS)
./vfkit-configs/truenas-scale.sh

# TrueNAS CORE (FreeBSD + ZFS)
./vfkit-configs/truenas-core.sh
```

### Check Disk Usage
```bash
du -sh ~/.vfkit/*
```

### Delete VMs
```bash
rm -rf ~/.vfkit/freebsd-zfs
rm -rf ~/.vfkit/openbsd
rm -rf ~/.vfkit/truenas-scale
rm -rf ~/.vfkit/truenas-core
```

---

**Status**: All BSD/TrueNAS VM configs created  
**Ready**: FreeBSD, OpenBSD, TrueNAS SCALE, TrueNAS CORE  
**ZFS Support**: FreeBSD ✅, TrueNAS ✅, OpenBSD ❌  
**Next**: Launch VMs and test!
