# ZFS Datadog Integration

[![Test](https://github.com/ryanmaclean/zfs-datadog-integration/actions/workflows/test.yml/badge.svg)](https://github.com/ryanmaclean/zfs-datadog-integration/actions/workflows/test.yml)

OpenZFS event monitoring with Datadog integration across 9 operating systems.

## Quick Start

```bash
# Install on Ubuntu/Debian
sudo ./scripts/install.sh

# Configure Datadog API key
sudo cp scripts/config.sh.example /etc/zfs/zed.d/config.sh
sudo vi /etc/zfs/zed.d/config.sh  # Set DD_API_KEY

# Validate configuration
sudo ./scripts/validate-config.sh

# Restart ZFS Event Daemon
sudo systemctl restart zfs-zed
```

**📖 [Full Installation Guide](INSTALL.md)** - Detailed instructions for all operating systems

## What This Does

Sends ZFS events to Datadog:
- Pool scrub completion
- Resilver completion  
- Pool state changes
- Checksum errors
- I/O errors

## Supported Operating Systems

**Tested & Production Ready**:
- Ubuntu 24.04 ✅
- Pop!_OS 22.04 ✅
- Debian 11+ ✅ (POSIX-compatible)

**Ready for Testing** (POSIX-compatible):
- RHEL/Rocky/AlmaLinux 8+
- Fedora, Arch Linux
- FreeBSD 13+
- TrueNAS SCALE & CORE
- OpenBSD, NetBSD
- OpenIndiana (Illumos)

See [INSTALL.md](INSTALL.md) for OS-specific instructions.

## Features

- **POSIX-compatible**: Works on Linux and BSD systems
- **Retry logic**: Exponential backoff (3 attempts, 1s/2s/4s)
- **Error handling**: Comprehensive logging and graceful degradation
- **Configuration validation**: Built-in config checker
- **Easy installation**: Automated install and uninstall scripts
- **CI/CD tested**: Automated testing with GitHub Actions

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
**Logging**: All events logged to Datadog

## Contributing

Issues and pull requests welcome! See [open issues](https://github.com/ryanmaclean/zfs-datadog-integration/issues) for areas that need work.

**Testing needed:**
- BSD systems (FreeBSD, OpenBSD, NetBSD)
- TrueNAS SCALE and CORE
- RHEL-based distributions
- OpenIndiana/Illumos

## Documentation

- **[INSTALL.md](INSTALL.md)** - Complete installation guide
- **[docs/BSD-COMPATIBILITY.md](docs/BSD-COMPATIBILITY.md)** - BSD-specific notes
- **[docs/IMPROVEMENTS-SUMMARY.md](docs/IMPROVEMENTS-SUMMARY.md)** - Technical details
- **[docs/TEST-COVERAGE.md](docs/TEST-COVERAGE.md)** - Test coverage matrix

## License

MIT License - See LICENSE file for details
