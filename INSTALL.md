# Installation Guide

Complete installation instructions for all supported operating systems.

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

**All Systems:**
- ZFS or OpenZFS installed and running
- ZFS Event Daemon (ZED) running
- curl (for HTTP API calls)
- Datadog account and API key ([Get one here](https://app.datadoghq.com/organization-settings/api-keys))

**Optional:**
- Datadog Agent (for metrics via DogStatsD)

---

## Quick Start (Ubuntu/Debian)

```bash
# 1. Clone repository
git clone https://github.com/ryanmaclean/zfs-datadog-integration.git
cd zfs-datadog-integration

# 2. Install zedlets
sudo ./scripts/install.sh

# 3. Configure Datadog API key
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY

# 4. Validate configuration
sudo ./scripts/validate-config.sh

# 5. Restart ZED
sudo systemctl restart zfs-zed

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
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo systemctl restart zfs-zed
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
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo systemctl restart zfs-zed
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
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo systemctl restart zfs-zed
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
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo systemctl restart zfs-zed
```

---

## BSD Systems

### FreeBSD

**Status:** POSIX-compatible, testing needed

**Install ZFS** (native on FreeBSD):
```bash
# ZFS is built into FreeBSD kernel
sudo sysrc zfs_enable="YES"
sudo service zfs start
```

**Install Integration:**
```bash
sudo ./scripts/install.sh

# Note: Path is /usr/local/etc/zfs/zed.d/ on FreeBSD
sudo cp scripts/config.sh.example /usr/local/etc/zfs/zed.d/config.sh
sudo vi /usr/local/etc/zfs/zed.d/config.sh  # Set DD_API_KEY

# Restart ZFS services
sudo service zfs restart
```

**Install Datadog Agent:**
```bash
pkg install datadog-agent
sudo sysrc datadog_enable="YES"
sudo service datadog start
```

---

### OpenBSD

**Status:** POSIX-compatible, testing needed

OpenBSD ZFS support is experimental. Refer to [BSD-COMPATIBILITY.md](docs/BSD-COMPATIBILITY.md) for details.

---

### NetBSD

**Status:** POSIX-compatible, testing needed

NetBSD has native ZFS support. Installation similar to FreeBSD.

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
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo systemctl restart zfs-zed
```

**⚠️ Important:** TrueNAS updates may overwrite custom scripts. Consider:
- Using Init/Shutdown Scripts in TrueNAS UI to reinstall after updates
- Keeping installation in persistent location

---

### TrueNAS CORE

**Status:** Ready for testing (FreeBSD-based)

TrueNAS CORE is FreeBSD-based. Use FreeBSD instructions with `/usr/local/etc/zfs/zed.d/` path.

**Installation:**
```bash
sudo ./scripts/install.sh
sudo cp scripts/config.sh.example /usr/local/etc/zfs/zed.d/config.sh
sudo vi /usr/local/etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo service zfs restart
```

**⚠️ Important:** Same update persistence concerns as TrueNAS SCALE.

---

## OpenIndiana / Illumos

**Status:** Testing needed

OpenIndiana has native ZFS (origin of ZFS).

**Installation:**
```bash
sudo ./scripts/install.sh
# Path may vary on Illumos
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY
sudo svcadm restart svc:/system/filesystem/zfs:default
```

**Note:** Datadog Agent availability for Solaris/Illumos is limited.

---

## Configuration

### Get Datadog API Key

1. Log in to [Datadog](https://app.datadoghq.com)
2. Go to **Organization Settings** → **API Keys**
3. Create or copy an API key

### Configure Integration

Edit the configuration file:
```bash
# Linux
sudo vi /etc/zfs/zed.d/config.sh

# FreeBSD/TrueNAS CORE
sudo vi /usr/local/etc/zfs/zed.d/config.sh
```

**Minimum configuration:**
```sh
DD_API_KEY="your_32_character_api_key"
DD_SITE="datadoghq.com"  # Or datadoghq.eu for EU
```

**Full configuration options:**
```sh
# Datadog Site
DD_SITE="datadoghq.com"  # US1
# DD_SITE="datadoghq.eu"  # EU
# DD_SITE="us3.datadoghq.com"  # US3
# DD_SITE="us5.datadoghq.com"  # US5

# Custom tags
DD_TAGS="env:production,service:zfs,datacenter:us-east-1"

# DogStatsD (requires Datadog Agent)
DOGSTATSD_HOST="localhost"
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
- API key is set
- ZED is running
- Zedlets are installed
- Network connectivity to Datadog

### Test Event Sending

```bash
# Trigger a scrub (safe on any pool)
sudo zpool scrub <poolname>

# Wait for scrub to complete (or cancel it)
sudo zpool scrub -s <poolname>

# Check ZED logs
sudo journalctl -u zfs-zed -n 50  # Linux
sudo cat /var/log/zed.log  # FreeBSD
```

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

# FreeBSD
sudo service zfs status
```

**Check zedlets are executable:**
```bash
# Linux
ls -la /etc/zfs/zed.d/*-datadog.sh

# FreeBSD
ls -la /usr/local/etc/zfs/zed.d/*-datadog.sh
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

**Check network connectivity:**
```bash
curl -X POST "https://api.datadoghq.com/api/v1/events" \
  -H "DD-API-KEY: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","text":"Test event"}'
```

### Permission denied

Ensure scripts are executable:
```bash
sudo chmod +x /etc/zfs/zed.d/*-datadog.sh
```

### API key invalid

Validate your API key:
```bash
curl -X GET "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: YOUR_API_KEY"
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
sudo systemctl restart zfs-zed

# FreeBSD
sudo rm -f /usr/local/etc/zfs/zed.d/*-datadog.sh
sudo rm -f /usr/local/etc/zfs/zed.d/config.sh
sudo service zfs restart
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
