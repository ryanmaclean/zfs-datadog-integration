# TrueNAS & FreeBSD Testing Guide

## Real TrueNAS & FreeBSD Images with QEMU

Since Lima has limited support for TrueNAS and FreeBSD, we use **QEMU directly** to test on real images.

## Available Test Scripts

### 1. TrueNAS SCALE (Debian-based) 🆕
**Script**: `qemu-truenas-scale.sh`
```bash
./qemu-truenas-scale.sh
```

**Details:**
- **Image**: TrueNAS SCALE 24.04.2.2 (Dragonfish)
- **URL**: https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.2/TrueNAS-SCALE-24.04.2.2.iso
- **Size**: ~1.4GB ISO
- **Base**: Debian 12 (Bookworm)
- **OpenZFS**: 2.2.x
- **Architecture**: x86_64 (will emulate on ARM64)
- **Ports**: SSH on 2222, Web UI on 8443

### 2. TrueNAS CORE (FreeBSD-based) 🆕
**Script**: `qemu-truenas-core.sh`
```bash
./qemu-truenas-core.sh
```

**Details:**
- **Image**: TrueNAS CORE 13.3-RELEASE
- **URL**: https://download-core.sys.truenas.net/13.3/STABLE/RELEASE/x64/TrueNAS-13.3-RELEASE.iso
- **Size**: ~700MB ISO
- **Base**: FreeBSD 13.3
- **ZFS**: Native FreeBSD ZFS
- **Architecture**: x86_64 only
- **Ports**: SSH on 2223, Web UI on 8444
- **Zedlet Path**: `/usr/local/etc/zfs/zed.d/`

### 3. FreeBSD 14.2 (Cloud Image) 🆕
**Script**: `qemu-freebsd.sh`
```bash
./qemu-freebsd.sh
```

**Details:**
- **Image**: FreeBSD 14.2-RELEASE BASIC-CLOUDINIT
- **URL**: https://download.freebsd.org/releases/VM-IMAGES/14.2-RELEASE/
- **ARM64**: Native support
- **AMD64**: Native support
- **ZFS**: Built-in (no installation needed)
- **Port**: SSH on 2224
- **Login**: freebsd/freebsd or root/freebsd
- **Zedlet Path**: `/usr/local/etc/zfs/zed.d/`

## Prerequisites

### Install QEMU
```bash
brew install qemu
```

### Optional: ISO creation tools (for FreeBSD cloud-init)
```bash
brew install cdrtools
```

## Usage Workflow

### TrueNAS SCALE Testing

1. **Start VM:**
   ```bash
   ./qemu-truenas-scale.sh
   ```

2. **Install TrueNAS SCALE:**
   - Follow installer prompts
   - Set root password
   - Configure network
   - Reboot

3. **Access Web UI:**
   ```bash
   open https://localhost:8443
   ```

4. **Enable SSH:**
   - System Settings → Services → SSH → Enable

5. **Copy zedlets:**
   ```bash
   scp -P 2222 *.sh root@localhost:/tmp/
   ```

6. **Install zedlets:**
   ```bash
   ssh -p 2222 root@localhost
   cd /tmp
   chmod +x install.sh
   ./install.sh
   ```

7. **Test:**
   ```bash
   # Create test pool
   zpool create testpool /dev/da1
   
   # Trigger scrub
   zpool scrub testpool
   
   # Check Datadog events
   ```

### TrueNAS CORE Testing

1. **Start VM:**
   ```bash
   ./qemu-truenas-core.sh
   ```

2. **Install TrueNAS CORE:**
   - Follow installer prompts
   - Configure network
   - Set root password

3. **Access Web UI:**
   ```bash
   open https://localhost:8444
   ```

4. **Enable SSH:**
   - System Settings → Services → SSH → Enable

5. **Copy zedlets:**
   ```bash
   scp -P 2223 *.sh root@localhost:/tmp/
   ```

6. **Install manually (different paths):**
   ```bash
   ssh -p 2223 root@localhost
   
   # Copy to FreeBSD ZED directory
   cp /tmp/zfs-datadog-lib.sh /usr/local/etc/zfs/zed.d/
   cp /tmp/config.sh /usr/local/etc/zfs/zed.d/
   cp /tmp/*-datadog.sh /usr/local/etc/zfs/zed.d/
   cp /tmp/*-error.sh /usr/local/etc/zfs/zed.d/
   
   # Set permissions
   chmod 755 /usr/local/etc/zfs/zed.d/*.sh
   chmod 600 /usr/local/etc/zfs/zed.d/config.sh
   
   # Configure API key
   vi /usr/local/etc/zfs/zed.d/config.sh
   
   # Restart ZED
   service zfs-zed restart
   ```

### FreeBSD Testing

1. **Start VM:**
   ```bash
   ./qemu-freebsd.sh
   ```

2. **Wait for boot (cloud-init takes ~2 minutes)**

3. **SSH into VM:**
   ```bash
   ssh -p 2224 freebsd@localhost
   # Password: freebsd
   ```

4. **Copy zedlets:**
   ```bash
   scp -P 2224 *.sh freebsd@localhost:/tmp/
   ```

5. **Install zedlets:**
   ```bash
   ssh -p 2224 freebsd@localhost
   sudo su -
   
   # Install to FreeBSD ZED directory
   cp /tmp/zfs-datadog-lib.sh /usr/local/etc/zfs/zed.d/
   cp /tmp/config.sh /usr/local/etc/zfs/zed.d/
   cp /tmp/*-datadog.sh /usr/local/etc/zfs/zed.d/
   cp /tmp/*-error.sh /usr/local/etc/zfs/zed.d/
   
   chmod 755 /usr/local/etc/zfs/zed.d/*.sh
   chmod 600 /usr/local/etc/zfs/zed.d/config.sh
   
   # Configure
   vi /usr/local/etc/zfs/zed.d/config.sh
   
   # Restart ZED
   service zfs-zed restart
   ```

6. **Test:**
   ```bash
   # Create test pool
   sudo zpool create testpool /dev/da1
   
   # Trigger scrub
   sudo zpool scrub testpool
   ```

## Path Differences

| System | ZED Directory | Service Command |
|--------|---------------|-----------------|
| **TrueNAS SCALE** | `/etc/zfs/zed.d/` | `systemctl restart zfs-zed` |
| **TrueNAS CORE** | `/usr/local/etc/zfs/zed.d/` | `service zfs-zed restart` |
| **FreeBSD** | `/usr/local/etc/zfs/zed.d/` | `service zfs-zed restart` |
| **Linux** | `/etc/zfs/zed.d/` | `systemctl restart zfs-zed` |

## Performance Notes

### Native ARM64
- **FreeBSD ARM64**: Full native performance
- **Startup**: ~2 minutes

### x86_64 Emulation on ARM64
- **TrueNAS SCALE**: ~10x slower (emulated)
- **TrueNAS CORE**: ~10x slower (emulated)
- **Startup**: 5-10 minutes
- **Use Case**: Testing only, not for performance benchmarks

### Native x86_64
- **All systems**: Full native performance on Intel Macs

## Disk Images

All scripts create persistent disk images:
- `truenas-scale-disk.qcow2` - TrueNAS SCALE data
- `truenas-core-disk.qcow2` - TrueNAS CORE data
- `freebsd-arm64.qcow2` or `freebsd-amd64.qcow2` - FreeBSD data

**To start fresh:**
```bash
rm *.qcow2
./qemu-*.sh  # Will recreate disk
```

## Network Configuration

### Port Forwarding
- **TrueNAS SCALE**: SSH 2222, HTTPS 8443
- **TrueNAS CORE**: SSH 2223, HTTPS 8444
- **FreeBSD**: SSH 2224

### Access from Host
```bash
# SSH
ssh -p 2222 root@localhost  # TrueNAS SCALE
ssh -p 2223 root@localhost  # TrueNAS CORE
ssh -p 2224 freebsd@localhost  # FreeBSD

# Web UI
open https://localhost:8443  # TrueNAS SCALE
open https://localhost:8444  # TrueNAS CORE
```

## Troubleshooting

### QEMU Not Found
```bash
brew install qemu
```

### VM Won't Boot
```bash
# Check QEMU version
qemu-system-aarch64 --version

# Try with more memory
# Edit script: -m 16G
```

### SSH Connection Refused
```bash
# Wait for boot to complete
# Check if SSH is enabled in TrueNAS UI
# Verify port forwarding
netstat -an | grep 2222
```

### Slow Performance
- This is expected for x86_64 emulation on ARM64
- Use for testing only, not benchmarks
- Consider using actual hardware for performance testing

### FreeBSD Cloud-Init Not Working
```bash
# Install ISO creation tools
brew install cdrtools

# Manually set password after boot
# Login as root (no password initially)
passwd freebsd
passwd root
```

## Testing Checklist

### TrueNAS SCALE
- [ ] VM boots successfully
- [ ] Web UI accessible
- [ ] SSH enabled
- [ ] Zedlets copied
- [ ] Zedlets installed
- [ ] Test pool created
- [ ] Scrub triggered
- [ ] Events captured in Datadog
- [ ] POSIX scripts work

### TrueNAS CORE
- [ ] VM boots successfully
- [ ] Web UI accessible
- [ ] SSH enabled
- [ ] Zedlets copied to `/usr/local/etc/zfs/zed.d/`
- [ ] Zedlets installed
- [ ] ZED restarted with `service zfs-zed restart`
- [ ] Test pool created
- [ ] Scrub triggered
- [ ] Events captured in Datadog
- [ ] POSIX scripts work on FreeBSD

### FreeBSD
- [ ] VM boots successfully
- [ ] Cloud-init completes
- [ ] SSH accessible
- [ ] ZFS available (built-in)
- [ ] Zedlets copied
- [ ] Zedlets installed
- [ ] Test pool created
- [ ] Scrub triggered
- [ ] Events captured
- [ ] POSIX scripts work

## Cleanup

### Stop VMs
```bash
# VMs stop when you close the QEMU window
# Or press Ctrl+C in terminal
```

### Remove All Test Data
```bash
rm truenas-*.iso
rm truenas-*.qcow2
rm freebsd-*.qcow2*
rm cloud-init-freebsd.iso
rm -rf cloud-init-freebsd/
```

## Next Steps

1. **Run QEMU tests**: Test on real TrueNAS and FreeBSD
2. **Validate POSIX compatibility**: Verify scripts work on BSD
3. **Document findings**: Update test results
4. **Production deployment**: Deploy on real hardware

## Resources

- [TrueNAS Downloads](https://www.truenas.com/download-truenas-scale/)
- [FreeBSD Downloads](https://www.freebsd.org/where/)
- [QEMU Documentation](https://www.qemu.org/documentation/)
- [TrueNAS Documentation](https://www.truenas.com/docs/)
