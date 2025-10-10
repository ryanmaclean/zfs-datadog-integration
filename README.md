# ZFS Datadog Integration

OpenZFS event monitoring with Datadog integration across 9 operating systems.

## Quick Start

```bash
# Install on Ubuntu/Debian
sudo ./install.sh

# Configure Datadog API key
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY

# Restart ZFS Event Daemon
sudo systemctl restart zfs-zed
```

## What This Does

Sends ZFS events to Datadog:
- Pool scrub completion
- Resilver completion  
- Pool state changes
- Checksum errors
- I/O errors

## Supported Operating Systems

**Tested**:
- Ubuntu 24.04 ✅
- Pop!_OS 22.04 ✅

**Packer Templates** (building):
- Ubuntu, Debian, Arch Linux
- Rocky Linux, Fedora
- FreeBSD, OpenBSD, NetBSD
- OpenIndiana

## Files

**Core**:
- `install.sh` - Installation script
- `config.sh` - Configuration
- `zfs-datadog-lib.sh` - Library functions
- `*-datadog.sh` - Event handlers (7 scripts)

**Packer**:
- `packer-*-zfs.pkr.hcl` - Build templates (9 OSes)
- `http/` - Cloud-init configs

**Scripts**: `scripts/` - Testing and automation
**Docs**: `docs/` - Status reports and documentation

## Architecture

```
ZFS Event → zed → zedlet → HTTP POST → Datadog API
```

**Retry logic**: Exponential backoff (3 attempts)
**Logging**: All events logged to Datadog

## Development

**Build all OS images**:
```bash
cd /tank3/vms
export DD_API_KEY=your_key
./scripts/build-all-packer.sh
```

**Test**:
```bash
./scripts/test-all-packer-images.sh
```

## Status

- **Core**: Production-ready
- **Packer builds**: In progress (9 OSes)
- **Testing**: Automated scripts ready
- **Datadog**: Agent configured, logs streaming

See `docs/` for detailed status reports.
