# Installation Guide

ZED installation instructions for hosts with a verified ZED service. FreeBSD base and TrueNAS CORE are excluded until a native Agent event path is validated.

An installer exit code, ZED restart, or handler exit code is not a Datadog intake receipt. Verify a controlled event at intake before treating a host as monitored.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start (Ubuntu/Debian)](#quick-start-ubuntudebian)
- [Linux Distributions](#linux-distributions)
  - [Ubuntu / Debian](#ubuntu--debian)
  - [RHEL / Rocky / AlmaLinux](#rhel--rocky--almalinux)
  - [Arch Linux](#arch-linux)
  - [Fedora](#fedora)
- [BSD Systems](#bsd-systems)
  - [FreeBSD](#freebsd)
  - [OpenBSD](#openbsd)
  - [NetBSD](#netbsd)
- [TrueNAS](#truenas)
  - [TrueNAS SCALE](#truenas-scale)
  - [TrueNAS CORE](#truenas-core)
- [OpenIndiana / Illumos](#openindiana--illumos)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

---

## Prerequisites

**Linux ZED hosts only:**
- ZFS or OpenZFS installed and running
- ZFS Event Daemon (ZED) running
- A running local Datadog Agent with DogStatsD on 127.0.0.1:8125
- `nc` and `openssl` available on the host

---

## Quick Start (Ubuntu/Debian)

```bash
# 1. Clone repository
git clone https://github.com/ryanmaclean/zfs-datadog-integration.git
cd zfs-datadog-integration

# 2. Install zedlets
sudo ./scripts/install.sh

# 3. Review local Agent endpoint and tags
sudo vi /etc/zfs/zed.d/config.sh

# 4. Validate configuration
sudo ./scripts/validate-config.sh

# 5. Confirm both services remain active after installer activation
sudo systemctl is-active zfs-zed datadog-agent

# 6. Test (optional)
sudo zpool scrub <poolname>
# Check Datadog for events
```

---

## Linux Distributions

### Ubuntu / Debian

**Tested:** Ubuntu 24.04, Pop!_OS 22.04

**Install OpenZFS:**
```bash
sudo apt update
sudo apt install -y zfsutils-linux
```

**Install Integration:**
```bash
sudo ./scripts/install.sh
sudo vi /etc/zfs/zed.d/config.sh  # Review tags and loopback port
sudo systemctl is-active zfs-zed datadog-agent
```

**Verify:**
```bash
sudo ./scripts/validate-config.sh
sudo systemctl status zfs-zed
```

---

### RHEL / Rocky / AlmaLinux

**Install OpenZFS:**
```bash
# Rocky Linux 9
sudo dnf install -y https://zfsonlinux.org/epel/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm
sudo dnf install -y kernel-devel zfs

# Load ZFS module
sudo modprobe zfs
```

**Install Integration:**
```bash
sudo ./scripts/install.sh
sudo vi /etc/zfs/zed.d/config.sh  # Review tags and loopback port
sudo systemctl is-active zfs-zed datadog-agent
```

**SELinux Note:**
If SELinux is enforcing, you may need to adjust policies:
```bash
sudo setsebool -P domain_can_mmap_files 1
# Or create custom policy (contact support)
```

---

### Arch Linux

**Install OpenZFS:**
```bash
# Install from AUR
yay -S zfs-dkms zfs-utils
# Or
paru -S zfs-dkms zfs-utils

# Load module
sudo modprobe zfs
```

**Install Integration:**
```bash
sudo ./scripts/install.sh
sudo vi /etc/zfs/zed.d/config.sh  # Review tags and loopback port
sudo systemctl is-active zfs-zed datadog-agent
```

---

### Fedora

**Install OpenZFS:**
```bash
sudo dnf install -y https://zfsonlinux.org/fedora/zfs-release$(rpm -E %fedora).noarch.rpm
sudo dnf install -y kernel-devel zfs

sudo modprobe zfs
```

**Install Integration:**
```bash
sudo ./scripts/install.sh
sudo vi /etc/zfs/zed.d/config.sh  # Review tags and loopback port
sudo systemctl is-active zfs-zed datadog-agent
```

---

## BSD Systems

### FreeBSD

**Status: unavailable through this installer.** FreeBSD base uses `zfsd` and `devd`, not a ZED zedlet dispatcher. `scripts/install.sh` exits before directory creation, key/config copy or service restart on FreeBSD. The separate native Datadog Agent `devd` check has not passed FreeBSD host-to-intake validation. Do not create `/usr/local/etc/zfs/zed.d` or restart `zfsd` to try to activate these zedlets. Keep existing ZFS services and pools untouched.

### OpenBSD

**Status:** no verified native event route; the Linux ZED installer rejects OpenBSD.

OpenBSD ZFS support is experimental. Refer to [BSD-COMPATIBILITY.md](docs/BSD-COMPATIBILITY.md) for details.

---

### NetBSD

**Status:** no verified native event route; the Linux ZED installer rejects NetBSD.

NetBSD has native ZFS support. A separately verified ZED service and integration test are required before using these ZED instructions.

---

## TrueNAS

### TrueNAS SCALE

**Status:** Ready for testing (Debian-based)

TrueNAS SCALE is Debian-based, so standard Linux installation applies.

**Installation:**
1. SSH into TrueNAS SCALE
2. Clone repository to persistent location
3. Run installation:
```bash
sudo ./scripts/install.sh
sudo vi /etc/zfs/zed.d/config.sh  # Review tags and loopback port
sudo systemctl is-active zfs-zed datadog-agent
```

**⚠️ Important:** TrueNAS updates may overwrite custom scripts. Consider:
- Using Init/Shutdown Scripts in TrueNAS UI to reinstall after updates
- Keeping installation in persistent location

---

### TrueNAS CORE

**Status: unavailable through this installer.** TrueNAS CORE is FreeBSD-based and shares the `zfsd`/`devd` boundary above. Do not use the former FreeBSD ZED directory, `service zfs restart`, or these ZED zedlets as evidence of Datadog event delivery. Wait for a verified native Agent route and a platform-specific deployment plan.

---

## OpenIndiana / Illumos

**Status:** no verified native event route; the Linux ZED installer rejects Illumos.

OpenIndiana has native ZFS (origin of ZFS).

Do not use the Linux installer or restart the ZFS service to infer event delivery.

---

## Configuration

### Configure Integration

Edit the configuration file:
```bash
# Linux
sudo vi /etc/zfs/zed.d/config.sh
```

**Minimum configuration:**
```sh
DOGSTATSD_HOST="127.0.0.1"
DOGSTATSD_PORT="8125"
```

**Full configuration options:**
```sh
# ZFS-specific tags. Set env and other host-wide tags in the local Agent's
# datadog.yaml; the Agent also supplies host identity.
DD_TAGS="service:zfs,team:storage"

# DogStatsD (requires Datadog Agent)
DOGSTATSD_HOST="127.0.0.1"
DOGSTATSD_PORT="8125"

# Enable/disable monitoring
MONITOR_POOL_HEALTH="true"
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
```

---

## Verification

### Validate Configuration

```bash
sudo ./scripts/validate-config.sh
```

This checks:
- Configuration file exists
- DogStatsD endpoint and tags are valid
- ZED is running
- Zedlets are installed
- Local Datadog Agent service is running

### Test Event Sending

Coordinate a controlled ZFS event with the host owner. Check ZED and Agent logs, then verify the event at Datadog intake. Do not initiate or cancel a scrub solely to test this integration without a maintenance plan.

### Check Datadog

1. Go to [Datadog Events](https://app.datadoghq.com/event/explorer)
2. Search for `source:zfs`
3. You should see events from your system

---

## Troubleshooting

### No events in Datadog

**Check ZED is running:**
```bash
# Linux
sudo systemctl status zfs-zed
sudo journalctl -u zfs-zed -n 100
```

**Check zedlets are executable:**
```bash
# Linux
ls -la /etc/zfs/zed.d/*-datadog.sh
```

**Test manually:**
```bash
# Set environment (simulate ZED)
export ZEVENT_CLASS="scrub_finish"
export ZEVENT_POOL="testpool"
export ZEVENT_SUBCLASS="scrub_finish"

# Run zedlet
sudo /etc/zfs/zed.d/scrub_finish-datadog.sh
```

**Check local Agent service and logs:**
```bash
sudo systemctl status datadog-agent
sudo journalctl -u datadog-agent -n 100
```

### Permission denied

Ensure scripts are executable:
```bash
sudo chmod +x /etc/zfs/zed.d/*-datadog.sh
```

### Scripts not running

Check ZED configuration:
```bash
# Linux
cat /etc/zfs/zed.d/zed.rc

# Should have:
ZED_SCRUB_AFTER_RESILVER=1
```

---

## Uninstallation

### Remove Integration

```bash
# Remove all zedlets
sudo ./scripts/uninstall.sh

# Keep configuration for future reinstall
sudo ./scripts/uninstall.sh --keep-config

# Dry run (show what would be removed)
sudo ./scripts/uninstall.sh --dry-run
```

### Manual Removal

```bash
# Linux
sudo rm -f /etc/zfs/zed.d/*-datadog.sh
sudo rm -f /etc/zfs/zed.d/config.sh
sudo systemctl is-active zfs-zed datadog-agent
```

---

## Support

- **Issues:** [GitHub Issues](https://github.com/ryanmaclean/zfs-datadog-integration/issues)
- **Documentation:** [docs/](docs/)
- **BSD Compatibility:** [docs/BSD-COMPATIBILITY.md](docs/BSD-COMPATIBILITY.md)

---

## Next Steps

- Set up [Datadog Dashboards](https://app.datadoghq.com/dashboard/lists) for ZFS monitoring
- Configure [Monitors](https://app.datadoghq.com/monitors/create) for critical events
- Review [docs/TEST-COVERAGE.md](docs/TEST-COVERAGE.md) for supported events
