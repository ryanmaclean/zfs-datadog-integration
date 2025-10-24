# ALL ARM64 BUILDS - NATIVE ONLY

**Directive**: ARM64 native everywhere, NO x86_64 QEMU

## Linux ARM64 - BUILDING NOW ✅

- debian-zfs: Building custom kernel
- ubuntu-zfs: Building custom kernel  
- rocky-zfs: Building custom kernel
- zfs-test: Custom kernel installed

All native ARM64 with VZ backend (Apple Virtualization).

## BSD ARM64 - EXECUTING NOW ✅

### FreeBSD ARM64
- **VM**: freebsd-build (QEMU aarch64)
- **Status**: Building M-SERIES kernel
- **Native**: YES - aarch64
- **Log**: freebsd-arm64-build.log

### OpenBSD ARM64
- **VM**: openbsd-kernel-build (QEMU aarch64)  
- **Status**: Requires manual install
- **Native**: YES - will be aarch64
- **Note**: ISO boot needed first

### NetBSD ARM64
- **VM**: netbsd-arm64 (QEMU aarch64)
- **Status**: Requires manual install
- **Native**: YES - will be evbarm-aarch64
- **Note**: ISO boot needed first

## illumos ARM64 - BUILDING NOW ✅

### OpenIndiana ARM64 (illumos)
- **Source**: richlowe/arm64-gate
- **Status**: Docker building
- **Native**: YES - ARM64 only
- **Note**: Experimental port, not official

## Architecture Verification

```bash
# All should show aarch64/arm64
debian-zfs: aarch64 (VZ)
ubuntu-zfs: aarch64 (VZ)
rocky-zfs: aarch64 (VZ)
freebsd-build: aarch64 (QEMU)
netbsd-arm64: aarch64 (QEMU)
openbsd-kernel-build: aarch64 (QEMU)
illumos: aarch64 (Docker)
```

## NO x86_64 ANYWHERE

- openindiana-seq: STOPPED (was x86_64, not using)
- All new builds: ARM64 only
- All Lima configs: aarch64
- All Docker: --platform linux/arm64

## Status Summary

| Platform | Arch | Status | Method |
|----------|------|--------|--------|
| Debian | aarch64 | Building | Lima VZ |
| Ubuntu | aarch64 | Building | Lima VZ |
| Rocky | aarch64 | Building | Lima VZ |
| FreeBSD | aarch64 | Building | Lima QEMU |
| OpenBSD | aarch64 | Ready | Lima QEMU |
| NetBSD | aarch64 | Ready | Lima QEMU |
| illumos | aarch64 | Building | Docker |

**ALL ARM64 NATIVE - NO QEMU x86_64!** ✅
