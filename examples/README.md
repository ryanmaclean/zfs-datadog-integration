# Examples

This directory contains example configurations for testing and development.

## Lima VM Configurations

The `lima/` directory contains VM configurations for testing on different operating systems:

- **lima-arch.yaml** - Arch Linux with ZFS
- **lima-debian.yaml** - Debian with OpenZFS
- **lima-fedora.yaml** - Fedora with OpenZFS
- **lima-freebsd.yaml** - FreeBSD with native ZFS
- **lima-openindiana.yaml** - OpenIndiana (Illumos) with native ZFS
- **lima-rocky.yaml** - Rocky Linux with OpenZFS
- **lima-zfs.yaml** - Ubuntu with ZFS (reference)

### Usage

```bash
# Start a VM
limactl start examples/lima/lima-ubuntu.yaml

# Access the VM
limactl shell lima-ubuntu

# Stop the VM
limactl stop lima-ubuntu

# Delete the VM
limactl delete lima-ubuntu
```

## Packer Templates

See `../packer/` directory for Packer templates to build golden images.

## Mock Datadog Server

For testing without a real Datadog account:

```bash
# Start mock server
python3 mock-datadog-server.py

# Configure scripts to use mock server
export DD_API_URL="http://localhost:8080"
```
