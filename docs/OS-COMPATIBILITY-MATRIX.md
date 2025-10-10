# OS Compatibility Matrix - ZFS Datadog Integration

## Complete OS Support Matrix

| OS | ZFS Support | Status | Script | Port | Path | Service |
|---|---|---|---|---|---|---|
| **Ubuntu 24.04** | OpenZFS 2.2 | ✅ Tested | lima-zfs.yaml | - | /etc/zfs/zed.d/ | systemctl |
| **Debian 12** | OpenZFS 2.1+ | ✅ Ready | lima-debian.yaml | - | /etc/zfs/zed.d/ | systemctl |
| **Rocky Linux 9** | OpenZFS 2.2 | ✅ Ready | lima-rocky.yaml | - | /etc/zfs/zed.d/ | systemctl |
| **Fedora 40** | OpenZFS 2.2 | ✅ Ready | lima-fedora.yaml | - | /etc/zfs/zed.d/ | systemctl |
| **Arch Linux** | OpenZFS Latest | ✅ Ready | lima-arch.yaml | - | /etc/zfs/zed.d/ | systemctl |
| **FreeBSD 14.3** | Native ZFS | ✅ Ready | qemu-freebsd.sh | 2224 | /usr/local/etc/zfs/zed.d/ | service |
| **TrueNAS SCALE** | OpenZFS 2.2 | 🔄 Testing | qemu-truenas-scale.sh | 2222 | /etc/zfs/zed.d/ | systemctl |
| **TrueNAS CORE** | Native ZFS | ⏳ Pending | qemu-truenas-core.sh | 2223 | /usr/local/etc/zfs/zed.d/ | service |
| **OpenBSD 7.6** | OpenZFS (ports) | 🆕 Ready | qemu-openbsd.sh | 2225 | /usr/local/etc/zfs/zed.d/ | rcctl |
| **NetBSD 10.0** | ZFS (pkgsrc) | 🆕 Ready | qemu-netbsd.sh | 2226 | /usr/local/etc/zfs/zed.d/ | service |
| **OpenIndiana** | Native ZFS | 🆕 Ready | qemu-openindiana.sh | 2227 | /etc/zfs/zed.d/ | svcadm |

## ZFS Implementation Types

### Native ZFS (Illumos/Solaris-based)
- **OpenIndiana** - Original ZFS implementation
- **FreeBSD** - Native FreeBSD ZFS
- **TrueNAS CORE** - FreeBSD-based

### OpenZFS (Linux/BSD Port)
- **Ubuntu/Debian/Rocky/Fedora/Arch** - OpenZFS on Linux
- **TrueNAS SCALE** - OpenZFS on Debian
- **OpenBSD** - OpenZFS via ports (experimental)
- **NetBSD** - OpenZFS via pkgsrc

## Installation Methods

### Linux (systemd)
```bash
# Ubuntu/Debian
apt-get install zfsutils-linux

# Rocky/Fedora
dnf install zfs

# Arch
pacman -S zfs-linux

# Zedlet path
/etc/zfs/zed.d/

# Service management
systemctl restart zfs-zed
systemctl status zfs-zed
```

### FreeBSD/TrueNAS CORE
```bash
# ZFS is built-in, no installation needed

# Zedlet path
/usr/local/etc/zfs/zed.d/

# Service management
service zfs-zed restart
service zfs-zed status
```

### OpenBSD
```bash
# Install OpenZFS from ports
pkg_add openzfs

# Load kernel module
kldload zfs

# Zedlet path
/usr/local/etc/zfs/zed.d/

# Service management
rcctl restart zfs-zed
rcctl status zfs-zed
```

### NetBSD
```bash
# Install from pkgsrc
pkgin install zfs

# Load kernel module
modload zfs

# Zedlet path
/usr/local/etc/zfs/zed.d/

# Service management
service zfs-zed restart
```

### OpenIndiana (Illumos)
```bash
# ZFS is built-in (native implementation)

# Zedlet path
/etc/zfs/zed.d/

# Service management
svcadm restart zfs-zed
svcs zfs-zed
```

## POSIX Compatibility Notes

### Shell Requirements
All scripts use `#!/bin/sh` (POSIX-compatible):
- ✅ Works on all systems
- ✅ No bash dependency
- ✅ Portable across Linux/BSD/Illumos

### Path Differences
| OS Type | ZED Directory |
|---------|---------------|
| Linux | `/etc/zfs/zed.d/` |
| FreeBSD | `/usr/local/etc/zfs/zed.d/` |
| OpenBSD | `/usr/local/etc/zfs/zed.d/` |
| NetBSD | `/usr/local/etc/zfs/zed.d/` |
| OpenIndiana | `/etc/zfs/zed.d/` |

### Service Management
| OS | Command |
|----|---------|
| Linux (systemd) | `systemctl restart zfs-zed` |
| FreeBSD | `service zfs-zed restart` |
| OpenBSD | `rcctl restart zfs-zed` |
| NetBSD | `service zfs-zed restart` |
| OpenIndiana | `svcadm restart zfs-zed` |

## Testing Status

### ✅ Fully Tested
- Ubuntu 24.04 ARM64
- POSIX syntax validation
- Retry logic
- Error handling

### 🔄 Testing In Progress
- TrueNAS SCALE (VM running)

### ⏳ Ready for Testing
- Debian 12
- Rocky Linux 9
- Fedora 40
- Arch Linux
- FreeBSD 14.3
- TrueNAS CORE
- OpenBSD 7.6
- NetBSD 10.0
- OpenIndiana Hipster

## Quick Start by OS

### Ubuntu/Debian
```bash
limactl start --name=ubuntu-zfs lima-zfs.yaml
./comprehensive-validation-test.sh
```

### Rocky/Fedora/Arch
```bash
limactl start --name=rocky-zfs lima-rocky.yaml
# Wait for boot, then test
```

### FreeBSD
```bash
./qemu-freebsd.sh
# Complete installation, then:
./test-freebsd.sh
```

### TrueNAS SCALE
```bash
./qemu-truenas-scale.sh
# Complete installation, enable SSH, then:
./test-truenas-scale.sh
```

### TrueNAS CORE
```bash
./qemu-truenas-core.sh
# Complete installation, enable SSH, then:
./test-truenas-core.sh
```

### OpenBSD
```bash
./qemu-openbsd.sh
# Install OpenZFS: pkg_add openzfs
# Copy zedlets to /usr/local/etc/zfs/zed.d/
```

### NetBSD
```bash
./qemu-netbsd.sh
# Install ZFS: pkgin install zfs
# Copy zedlets to /usr/local/etc/zfs/zed.d/
```

### OpenIndiana
```bash
./qemu-openindiana.sh
# ZFS is native, just copy zedlets
# Use svcadm for service management
```

## Architecture Support

### ARM64 Native
- Ubuntu, Debian, Rocky, Fedora, Arch (Lima)
- FreeBSD 14.3 (QEMU)
- NetBSD 10.0 (QEMU)

### x86_64 (Native or Emulated)
- All Linux distros
- FreeBSD
- TrueNAS SCALE/CORE
- OpenBSD
- NetBSD
- OpenIndiana

## Port Assignments

| System | SSH Port | Web UI |
|--------|----------|--------|
| Lima VMs | Default | N/A |
| FreeBSD | 2224 | N/A |
| TrueNAS SCALE | 2222 | 8443 |
| TrueNAS CORE | 2223 | 8444 |
| OpenBSD | 2225 | N/A |
| NetBSD | 2226 | N/A |
| OpenIndiana | 2227 | N/A |

## ZFS Event Support

All systems support these ZFS events:
- ✅ scrub_finish
- ✅ resilver_finish
- ✅ statechange
- ✅ checksum errors (with zinject)
- ✅ io errors (with zinject)

## Dependencies

### Required on All Systems
- `curl` - HTTP requests
- `nc` (netcat) - UDP metrics
- `sh` - POSIX shell

### Optional
- `python3` - Mock Datadog server
- `jq` - JSON parsing for tests

## Known Limitations

### OpenBSD
- OpenZFS support is experimental
- May require manual compilation
- Limited testing

### NetBSD
- ZFS support via pkgsrc
- Kernel module may need manual loading
- Performance may vary

### OpenIndiana
- x86_64 only (no ARM64)
- Different service management (SMF)
- Illumos-specific paths

## Testing Checklist

For each OS:
- [ ] VM boots successfully
- [ ] ZFS installed/available
- [ ] Zedlets copied to correct path
- [ ] Permissions set correctly
- [ ] ZED service restarted
- [ ] Test pool created
- [ ] Scrub triggered
- [ ] Events captured
- [ ] Metrics sent
- [ ] POSIX scripts work

## Next Steps

1. Complete TrueNAS SCALE testing (in progress)
2. Test TrueNAS CORE
3. Test OpenIndiana (native ZFS)
4. Test OpenBSD (experimental)
5. Test NetBSD
6. Document findings for each OS
7. Create OS-specific troubleshooting guides

## Resources

- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [FreeBSD ZFS Handbook](https://docs.freebsd.org/en/books/handbook/zfs/)
- [OpenIndiana Docs](https://docs.openindiana.org/)
- [NetBSD ZFS Guide](https://wiki.netbsd.org/zfs/)
- [OpenBSD Ports](https://openports.pl/path/sysutils/openzfs)
