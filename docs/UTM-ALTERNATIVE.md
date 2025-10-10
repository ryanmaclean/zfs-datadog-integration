# UTM as Alternative Virtualization Solution

## What is UTM?

UTM is a full-featured virtual machine host for iOS and macOS. It's based on QEMU but provides a native macOS GUI interface.

**Website**: https://mac.getutm.app/  
**GitHub**: https://github.com/utmapp/UTM  

## Why UTM for This Project?

### Advantages Over Command-Line QEMU
1. ✅ **Native macOS GUI** - No command-line complexity
2. ✅ **Apple Silicon optimized** - Better ARM64 support
3. ✅ **x86_64 emulation** - Can run x86_64 VMs on ARM64
4. ✅ **Easy VM management** - Create, start, stop VMs easily
5. ✅ **Rosetta integration** - Can use Rosetta for x86_64 Linux
6. ✅ **Free and open source** - No license required

### Better Than Lima For
- BSD systems (FreeBSD, OpenBSD, NetBSD)
- TrueNAS SCALE/CORE
- OpenIndiana
- Any OS requiring manual installation

## Using UTM for ZFS Testing

### Step 1: Install UTM
```bash
# Via Homebrew
brew install --cask utm

# Or download from
# https://mac.getutm.app/
```

### Step 2: Create VMs

#### FreeBSD 14.3
1. Download ISO: https://download.freebsd.org/releases/ISO-IMAGES/14.3/
2. Create new VM in UTM
3. Select "Emulate" for x86_64 or "Virtualize" for ARM64
4. Allocate 4GB RAM, 2 CPUs, 20GB disk
5. Install FreeBSD
6. Copy zedlets to `/usr/local/etc/zfs/zed.d/`

#### TrueNAS SCALE
1. Use downloaded ISO: `truenas-scale.iso`
2. Create new VM in UTM
3. Select "Emulate" (x86_64)
4. Allocate 8GB RAM, 2 CPUs, 20GB disk
5. Install TrueNAS SCALE
6. Access web UI, enable SSH
7. Copy zedlets to `/etc/zfs/zed.d/`

#### OpenBSD 7.6
1. Download ISO: https://www.openbsd.org/faq/faq4.html
2. Create VM in UTM
3. Install OpenBSD
4. Install OpenZFS: `pkg_add openzfs`
5. Copy zedlets

### Step 3: Network Configuration

UTM provides easy port forwarding:
- FreeBSD: Forward host 2224 → guest 22
- TrueNAS SCALE: Forward host 2222 → guest 22, 8443 → guest 443
- OpenBSD: Forward host 2225 → guest 22

### Step 4: Test Zedlets

Same as before:
```bash
# Copy files
scp -P 2224 *.sh root@localhost:/tmp/

# Install (adjust path for OS)
ssh -p 2224 root@localhost
cd /tmp
# FreeBSD/OpenBSD: /usr/local/etc/zfs/zed.d/
# TrueNAS SCALE: /etc/zfs/zed.d/
```

## Comparison Matrix

| Feature | Lima | QEMU CLI | UTM | Parallels | VMware |
|---------|------|----------|-----|-----------|--------|
| **Cost** | Free | Free | Free | Paid | Free |
| **GUI** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **ARM64 Native** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **x86_64 Emulation** | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| **Linux Support** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **BSD Support** | ⚠️ | ✅ | ✅ | ⚠️ | ✅ |
| **Easy Setup** | ⚠️ | ❌ | ✅ | ✅ | ✅ |
| **Automation** | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ |

## Recommended Approach

### For Linux (Ubuntu, Debian, Rocky, Fedora, Arch)
**Use Lima** - Fast, automated, works great

### For BSD/TrueNAS/OpenIndiana
**Use UTM** - Much easier than command-line QEMU

### For Production Testing
**Use real hardware** or cloud instances

## UTM Configuration Examples

### FreeBSD VM (UTM)
```
Name: FreeBSD-ZFS
Architecture: x86_64 (Emulated)
System: Standard PC (Q35 + ICH9, 2009)
Memory: 4096 MB
CPU Cores: 2
Boot: FreeBSD-14.3-RELEASE-amd64-disc1.iso
Network: Shared Network
Port Forwarding: 2224 → 22
```

### TrueNAS SCALE VM (UTM)
```
Name: TrueNAS-SCALE
Architecture: x86_64 (Emulated)
System: Standard PC (Q35 + ICH9, 2009)
Memory: 8192 MB
CPU Cores: 2
Boot: TrueNAS-SCALE-24.04.2.2.iso
Network: Shared Network
Port Forwarding: 
  - 2222 → 22 (SSH)
  - 8443 → 443 (Web UI)
```

## Current Project Status with UTM

### What We Have
- ✅ Packer template (1): `packer-ubuntu-zfs.pkr.hcl`
- ✅ QEMU scripts (6): FreeBSD, OpenBSD, NetBSD, OpenIndiana, TrueNAS x2
- ✅ Lima configs (5): Ubuntu, Debian, Rocky, Fedora, Arch

### What UTM Would Add
- ✅ **Easier BSD testing** - GUI instead of stuck QEMU windows
- ✅ **Better TrueNAS testing** - Proper installation workflow
- ✅ **Simpler setup** - No command-line debugging
- ✅ **Better x86_64 emulation** - More reliable than raw QEMU

## Migration Path

### From QEMU Scripts to UTM

Instead of:
```bash
./qemu-freebsd.sh  # Gets stuck, hard to debug
```

Use UTM:
1. Open UTM app
2. Create new VM
3. Select ISO
4. Click Start
5. Complete installation in GUI
6. Use normally

### Automation with UTM

UTM can be scripted via CLI:
```bash
# List VMs
/Applications/UTM.app/Contents/MacOS/utmctl list

# Start VM
/Applications/UTM.app/Contents/MacOS/utmctl start "FreeBSD-ZFS"

# Stop VM
/Applications/UTM.app/Contents/MacOS/utmctl stop "FreeBSD-ZFS"
```

## Recommendation

**For completing BSD/TrueNAS testing:**

1. Install UTM: `brew install --cask utm`
2. Create VMs for:
   - FreeBSD 14.3
   - TrueNAS SCALE
   - TrueNAS CORE
   - OpenBSD (optional)
   - NetBSD (optional)
3. Install OSes via GUI
4. Test zedlets manually
5. Document results

**Estimated time**: 2-3 hours vs days of QEMU debugging

## Resources

- UTM Website: https://mac.getutm.app/
- UTM Documentation: https://docs.getutm.app/
- UTM Gallery (pre-made VMs): https://mac.getutm.app/gallery/
- GitHub: https://github.com/utmapp/UTM

## Conclusion

UTM is the **practical solution** for testing BSD and TrueNAS systems on Apple Silicon. Much easier than debugging QEMU command-line issues.

**Current project is production-ready for Ubuntu/Debian. Use UTM for additional platform validation as needed.**
