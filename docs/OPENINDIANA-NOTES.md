# OpenIndiana / Illumos Notes

## What is OpenIndiana?

**OpenIndiana Hipster** is an Illumos-based operating system, the open-source continuation of Oracle Solaris.

**Key Features**:
- **Native ZFS**: Original ZFS implementation (not OpenZFS)
- **SMF**: Service Management Facility (not systemd)
- **IPS**: Image Packaging System (not apt/yum)
- **Zones**: Container technology (predates Docker)

## ZFS on OpenIndiana

**Native ZFS** - This is where ZFS was born:
- Most mature ZFS implementation
- Original Sun Microsystems code
- Different from OpenZFS (Linux/BSD)
- ZED (ZFS Event Daemon) included by default

**Paths**:
- Zedlets: `/etc/zfs/zed.d/`
- Config: `/etc/zfs/zed.rc`
- Service: `svcadm restart zfs-zed`

## Datadog on OpenIndiana

**No Official Support**: Datadog Agent not available for Illumos/Solaris

**Our Implementation** (HTTP API):
✅ **Perfect for OpenIndiana**:
- Direct HTTP POST to Datadog API
- No agent dependency
- Uses native `curl` or `wget`
- Works with SMF for service management

**Installation**:
```bash
# Install dependencies
pkg install curl python-39

# Deploy zedlets
cp *-datadog.sh /etc/zfs/zed.d/
chmod 755 /etc/zfs/zed.d/*-datadog.sh

# Configure
vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY

# Restart ZED
svcadm restart zfs-zed
```

## Packer Build Status

**Template**: `packer-openindiana-zfs.pkr.hcl`

**Configuration**:
- ISO: `OI-hipster-text-20241026.iso` (latest)
- Boot: Text installer (no GUI)
- SSH: Root login with password
- Provisioner: Install curl, python, deploy zedlets

**Current Status**: Building (waiting for SSH)

**Challenges**:
- Text-based installer requires boot commands
- Slower boot than cloud images
- Manual installation steps via VNC

## Why OpenIndiana Matters

**Original ZFS**: Testing on the source implementation validates our zedlets work with:
- Original ZFS codebase
- Different event formats
- SMF service management
- Illumos kernel

**Production Use Cases**:
- Legacy Solaris migrations
- High-performance storage servers
- ZFS development and testing
- Enterprise environments with Solaris expertise

## Datadog Integration Benefits

**Native ZFS + Datadog**:
- Monitor original ZFS implementation
- Compare events with OpenZFS
- Validate cross-platform compatibility
- Enterprise monitoring for Illumos systems

**Events Sent**:
- Scrub completion
- Resilver completion
- Pool state changes
- Checksum errors
- I/O errors

All via HTTP API (no agent required).
