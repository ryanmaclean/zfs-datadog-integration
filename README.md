# ZFS Datadog Integration

[![Test](https://github.com/ryanmaclean/zfs-datadog-integration/actions/workflows/test.yml/badge.svg)](https://github.com/ryanmaclean/zfs-datadog-integration/actions/workflows/test.yml)

OpenZFS ZED event monitoring on hosts with a verified ZED service. FreeBSD base uses a different event path.

## Quick Start

```bash
# Install on Ubuntu/Debian
sudo ./scripts/install.sh

# Configure Datadog API key; installer seeds config.sh only when absent
sudo vi /etc/zfs/zed.d/config.sh  # Inspect an existing key before editing

# Validate configuration
sudo ./scripts/validate-config.sh

# Restart ZFS Event Daemon
sudo systemctl restart zfs-zed
```

**📖 [Full Installation Guide](INSTALL.md)** - Detailed instructions for all operating systems

## What This Does

Sends ZFS events to Datadog:
- Pool scrub completion
- **scrub_start**: ZFS pool scrub started (counter + in_progress gauge, info event)
- Resilver completion
- **resilver_start**: ZFS pool resilver started (counter + in_progress gauge, warning event)
- Pool state changes
- Checksum errors
- I/O errors
- Pool import/destroy
- Device attach/remove
- Configuration sync

## Supported Operating Systems

**Tested & Production Ready**:
- Ubuntu 24.04 ✅
- Pop!_OS 22.04 ✅
- Debian 11+ ✅ (POSIX-compatible)

**Ready for Testing** (POSIX-compatible):
- RHEL/Rocky/AlmaLinux 8+
- Fedora, Arch Linux
- TrueNAS SCALE (Linux ZED route, testing needed)
- OpenBSD, NetBSD
- OpenIndiana (Illumos)

**FreeBSD and TrueNAS CORE:** the ZED installer exits before writing files or restarting services. Base FreeBSD uses `zfsd`/`devd`; a native Datadog Agent event check has not passed host-to-intake validation. A ZED directory or `zfsd` restart does not establish monitoring.

On ZED hosts, an installer success message or zedlet exit status does not confirm Datadog intake. Validate the selected runtime tools' licenses and one controlled event at intake before calling a host monitored.

See [INSTALL.md](INSTALL.md) for OS-specific instructions.

## Features

- **POSIX shell**: ZED installer is disabled on FreeBSD base and TrueNAS CORE
- **Retry logic**: Exponential backoff (3 attempts, 1s/2s/4s)
- **Error handling**: Comprehensive logging and graceful degradation
- **Configuration validation**: Built-in config checker
- **Easy installation**: Automated install and uninstall scripts
- **CI/CD tested**: Automated testing with GitHub Actions
- **Telemetry-safe**: Next.js telemetry disabled across Docker, Kubernetes, and VM workflows ([details](infrastructure/kubernetes/nextjs-telemetry-patch.yaml))

## Tools

- **install.sh** - Automated installation
- **uninstall.sh** - Clean removal with --dry-run and --keep-config
- **validate-config.sh** - Configuration and connectivity validation
- **config.sh.example** - Configuration template

See [scripts/](scripts/) for all tools and [examples/](examples/) for VM configs.

## Architecture

```
ZFS Event → zed → zedlet → HTTP POST → Datadog API
```

**Retry logic**: Exponential backoff (3 attempts)
**Delivery**: Verify each event at Datadog intake; handler exit status is not proof

## Contributing

Issues and pull requests welcome! See [open issues](https://github.com/ryanmaclean/zfs-datadog-integration/issues) for areas that need work.

**Testing needed:**
- OpenBSD and NetBSD ZED routes
- TrueNAS SCALE and CORE
- RHEL-based distributions
- OpenIndiana/Illumos

## Documentation

- **[INSTALL.md](INSTALL.md)** - Complete installation guide

## License

MIT License - See LICENSE file for details
