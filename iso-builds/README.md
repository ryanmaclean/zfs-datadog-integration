# Custom ISO Builds for M-series

Since you're a **Gentoo maintainer**, building custom ISOs is straightforward!

## Why Build ISOs?

**Problem**: NetBSD and OpenBSD use installation ISOs that require manual setup.

**Solution**: Build custom ISOs with:
- M-series kernel pre-compiled
- ZFS pre-installed
- Auto-install configured
- Ready to boot and use

## ISO Builders

### 1. Gentoo M-series ISO

**File**: `build-gentoo-m-series-iso.sh`

**What it builds**:
- Gentoo ARM64 from stage3
- M-series optimized kernel (ARMv8.4-A+)
- ZFS compiled from source
- All packages optimized with `-march=armv8.4-a`
- Bootable ISO + SquashFS

**Time**: 2-3 hours (compiling everything)

**Result**: `gentoo-m-series-YYYYMMDD.iso`

**Advantages**:
- Everything compiled specifically for M-series
- No generic ARM binaries
- Maximum performance
- Full Gentoo power

---

### 2. NetBSD M-series ISO

**File**: `build-netbsd-m-series-iso.sh`

**What it builds**:
- NetBSD 10.0 ARM64 sets
- M-series kernel config
- Auto-install script
- ZFS from pkgsrc
- Bootable ISO

**Time**: 30 minutes

**Result**: `netbsd-m-series-YYYYMMDD.iso`

**Advantages**:
- Skip manual installation
- ZFS pre-configured
- Boot and go

---

### 3. OpenBSD M-series ISO

**File**: `build-openbsd-m-series-iso.sh`

**What it builds**:
- OpenBSD 7.6 ARM64
- Auto-install config
- M-series kernel config
- ZFS experimental setup

**Time**: 20 minutes

**Result**: `openbsd-m-series-YYYYMMDD.iso`

**Note**: OpenBSD + ZFS is experimental!

---

## Usage

### Build an ISO

```bash
cd iso-builds

# Gentoo (long but powerful)
sudo ./build-gentoo-m-series-iso.sh

# NetBSD (quick)
sudo ./build-netbsd-m-series-iso.sh

# OpenBSD (experimental)
sudo ./build-openbsd-m-series-iso.sh
```

### Use with Lima

```bash
# Point Lima config to your ISO
limactl start --name=gentoo-custom \
  --set '.images[0].location="/path/to/gentoo-m-series-20251023.iso"' \
  examples/lima/lima-gentoo-arm64.yaml
```

### Publish ISOs

```bash
# Upload to GitHub releases
gh release upload v1.0.0-isos \
  gentoo-m-series-*.iso \
  netbsd-m-series-*.iso \
  openbsd-m-series-*.iso
```

---

## Gentoo Maintainer Advantages

As a Gentoo maintainer, you can:

1. **Optimize everything** - Custom CFLAGS for M-series
2. **Control USE flags** - Minimal or full-featured
3. **Bleeding edge** - Latest packages compiled fresh
4. **Source-based** - No trust issues with binaries
5. **Reproducible** - Document exact emerge commands

### Example Gentoo Build

```bash
# In the ISO builder or manually

# Stage3 extraction
tar xpf stage3-arm64.tar.xz

# Chroot
chroot . /bin/bash

# Configure
cat > /etc/portage/make.conf << 'EOF'
COMMON_FLAGS="-O3 -pipe -march=armv8.4-a+crypto -mtune=cortex-a76"
MAKEOPTS="-j16"
USE="zfs minimal -X -gtk"
EOF

# Build world
emerge --sync
emerge -avuDN @world

# Build M-series kernel
cd /usr/src/linux
make menuconfig  # Use our config
make -j16 Image.gz modules
make modules_install

# Install ZFS
emerge sys-fs/zfs

# Done!
```

---

## ISO Formats

### Hybrid ISO
- Boots on UEFI (M-series)
- Boots on BIOS (x86_64 fallback)
- Includes auto-install

### SquashFS
- Compressed rootfs
- Fast decompression
- Smaller download

### Cloud Image
- QCOW2 format
- Ready for Lima/QEMU
- Pre-configured

---

## Publishing Strategy

1. **Build ISOs locally** (~3 hours for all)
2. **Test in Lima** (verify boot + ZFS)
3. **Create checksums** (SHA256)
4. **Upload to GitHub Release**
5. **Update Lima configs** with ISO URLs

---

## Future: Automated ISO Builds in CI

```yaml
# .github/workflows/build-isos.yml
jobs:
  build-gentoo-iso:
    runs-on: macos-14  # M-series runner
    steps:
      - name: Build Gentoo ISO
        run: sudo ./iso-builds/build-gentoo-m-series-iso.sh
      
      - name: Upload ISO
        uses: actions/upload-artifact@v4
        with:
          name: gentoo-m-series-iso
          path: /tmp/gentoo-build/gentoo-m-series-*.iso
```

---

## Why This Is Powerful

**Before**: Manual installation, 30+ minutes, error-prone

**After**: Boot ISO, auto-install, ready in 5 minutes

**Plus**: Everything optimized for M-series from source!

---

## Gentoo-Specific Tips

### Parallel Emerges
```bash
MAKEOPTS="-j16"  # Use all P+E cores
EMERGE_DEFAULT_OPTS="--jobs=4 --load-average=12"
```

### Binary Packages
```bash
# Build once, distribute
FEATURES="buildpkg"
quickpkg sys-fs/zfs  # Share ZFS binary
```

### M-series USE Flags
```bash
CPU_FLAGS_ARM="aes crc32 neon sha1 sha2"
```

---

**As a Gentoo maintainer, you can build the ultimate M-series optimized distro!** 🔥
