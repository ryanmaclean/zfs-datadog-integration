# 🗄️ Remote Storage Setup (Dev Environment)

**Purpose**: Use remote ZFS storage to save local disk space  
**Target**: i9-zfs-pop.local with tank3 ZFS pool  
**Benefit**: Store ISOs and VMs remotely, keep local Mac disk free

---

## 🎯 Quick Setup (Dev Environment)

### 1. Mount Remote Storage

```bash
# Mount tank3 from i9-zfs-pop.local
./scripts/mount-remote-storage.sh

# Or manually:
sudo mkdir -p /Volumes/tank3
sudo mount -t nfs i9-zfs-pop.local:/tank3 /Volumes/tank3
```

### 2. Verify Mount

```bash
df -h /Volumes/tank3
ls -la /Volumes/tank3
```

### 3. VMs Will Auto-Use Remote Storage

The `.env` file is already configured to use `/Volumes/tank3`:
```bash
VM_STORAGE_DIR="/Volumes/tank3/vms"
DOWNLOAD_CACHE_DIR="/Volumes/tank3/iso-cache"
```

---

## 📊 Storage Layout

### Remote (i9-zfs-pop.local:/tank3)
```
/tank3/
├── vms/                    # VM disk images
│   ├── freebsd-zfs/
│   ├── openbsd/
│   ├── truenas-scale/
│   └── truenas-core/
└── iso-cache/              # Downloaded ISOs
    ├── freebsd-14.2-arm64.qcow2
    ├── truenas-scale.iso
    └── truenas-core.iso
```

### Local (Mac)
```
~/.vfkit/                   # Only config files (minimal)
├── config-loader.sh
└── *.log                   # Console logs
```

---

## 🚀 Usage

### Start VMs (Auto-Uses Remote Storage)

```bash
# FreeBSD - downloads to /Volumes/tank3/iso-cache
./vfkit-configs/freebsd-zfs.sh

# TrueNAS SCALE - stores VM on /Volumes/tank3/vms
./vfkit-configs/truenas-scale.sh
```

### Check Disk Usage

```bash
# Remote storage
df -h /Volumes/tank3
du -sh /Volumes/tank3/vms/*
du -sh /Volumes/tank3/iso-cache/*

# Local storage (should be minimal)
du -sh ~/.vfkit
```

---

## 🔧 Configuration Files

### `.env` (Dev Environment - Already Created)
```bash
# Remote storage on i9-zfs-pop.local
VM_STORAGE_DIR="/Volumes/tank3/vms"
DOWNLOAD_CACHE_DIR="/Volumes/tank3/iso-cache"

REMOTE_ZFS_SERVER="i9-zfs-pop.local"
REMOTE_ZFS_PATH="/tank3"
REMOTE_ZFS_MOUNT="/Volumes/tank3"
```

### `.env.example` (For Other Users)
```bash
# Default: Local storage
VM_STORAGE_DIR="$HOME/.vfkit"
DOWNLOAD_CACHE_DIR="$HOME/.vfkit/downloads"

# Uncomment to use remote storage:
# VM_STORAGE_DIR="/Volumes/tank3/vms"
# DOWNLOAD_CACHE_DIR="/Volumes/tank3/iso-cache"
```

---

## 📋 Disk Space Comparison

### Without Remote Storage (Local Only)
```
FreeBSD ISO:       733MB
TrueNAS SCALE ISO: 2GB
TrueNAS CORE ISO:  800MB
FreeBSD VM:        4-5GB
TrueNAS VMs:       12-15GB each
─────────────────────────
Total:             ~35GB on local Mac
```

### With Remote Storage (Recommended)
```
Local Mac:         <1GB (configs only)
Remote (tank3):    ~35GB (ISOs + VMs)
─────────────────────────
Local savings:     34GB+ ✅
```

---

## 🎓 How It Works

### 1. Config Loader
All vfkit scripts source `config-loader.sh`:
```bash
# In each vfkit script:
source "$(dirname "$0")/config-loader.sh"

# This sets:
# - VM_STORAGE_DIR
# - DOWNLOAD_CACHE_DIR
# - Checks disk space
```

### 2. Path Resolution
```bash
# Instead of hardcoded:
VM_DIR="$HOME/.vfkit/freebsd-zfs"

# Now uses config:
VM_DIR="$VM_STORAGE_DIR/freebsd-zfs"
# Resolves to: /Volumes/tank3/vms/freebsd-zfs
```

### 3. Download Cache
```bash
# ISOs download to:
DOWNLOAD_CACHE_DIR="/Volumes/tank3/iso-cache"

# Shared across all VMs
# No duplicate downloads
```

---

## 🚨 Troubleshooting

### Mount Failed
```bash
# Check if server is reachable
ping i9-zfs-pop.local

# Check NFS service
ssh i9-zfs-pop.local "systemctl status nfs-server"

# Check ZFS pool
ssh i9-zfs-pop.local "zpool status tank3"
```

### Permission Denied
```bash
# Ensure NFS export allows your Mac
ssh i9-zfs-pop.local "cat /etc/exports"

# Should have:
# /tank3 *(rw,sync,no_subtree_check,no_root_squash)
```

### Unmount
```bash
# Unmount remote storage
sudo umount /Volumes/tank3

# Or force unmount
sudo umount -f /Volumes/tank3
```

---

## 🎯 For Other Users (Not Dev)

### Option 1: Use Local Storage (Default)
```bash
# Don't create .env file
# Scripts use default: ~/.vfkit
```

### Option 2: Use Their Own Remote Storage
```bash
# Copy .env.example to .env
cp .env.example .env

# Edit .env:
VM_STORAGE_DIR="/path/to/their/storage"
DOWNLOAD_CACHE_DIR="/path/to/their/cache"
```

### Option 3: Use External Drive
```bash
# Mount external drive
# Edit .env:
VM_STORAGE_DIR="/Volumes/ExternalDrive/vms"
DOWNLOAD_CACHE_DIR="/Volumes/ExternalDrive/iso-cache"
```

---

## 📊 Benefits

### Dev Environment
- ✅ Saves 35GB+ on local Mac
- ✅ Fast ZFS storage on i9-zfs-pop
- ✅ Shared ISO cache
- ✅ Easy cleanup (just unmount)

### Production/Users
- ✅ Works locally by default
- ✅ Configurable for any storage
- ✅ No hardcoded paths
- ✅ Portable across environments

---

## 🎓 Summary

**Dev Setup** (You):
1. Mount tank3: `./scripts/mount-remote-storage.sh`
2. VMs auto-use remote storage (configured in `.env`)
3. Save 35GB+ on local Mac

**User Setup** (Others):
1. Works locally by default (no setup needed)
2. Optional: Configure `.env` for their storage
3. Portable and flexible

---

**Status**: Remote storage configured for dev  
**Mount**: `./scripts/mount-remote-storage.sh`  
**Config**: `.env` (dev) and `.env.example` (users)  
**Savings**: 35GB+ on local Mac ✅
