# Packer Builds for M-series

All Packer templates share common M-series optimizations.

## Common Settings

See `common-m-series.pkrvars.hcl` for shared variables:

- **CPU**: cortex-a76 (best match for M1-M5)
- **Cores**: 8 (utilizes P+E cores)
- **Memory**: 8GB
- **Accelerator**: hvf (macOS Hypervisor - 2x faster than QEMU)
- **Architecture**: aarch64

## M-series Optimizations

### Hardware
- `cpu_model = "cortex-a76"` - Closest QEMU model to M-series
- `accelerator = "hvf"` - Native macOS virtualization
- `cpus = 8` - Leverage performance + efficiency cores

### Kernel Crypto (All Builds)
```
ARM64_CRYPTO=y
CRYPTO_AES_ARM64_CE=y      # AES acceleration
CRYPTO_SHA256_ARM64=y      # SHA acceleration
CRYPTO_CRC32_ARM64_CE=y    # CRC32 acceleration
```

### Alpine Additional
```
ARM64_PAGE_SHIFT=14        # 16K pages (vs 4K)
```

## Usage

### Build All
```bash
# Alpine
packer build alpine-m-series.pkr.hcl

# FreeBSD
packer build freebsd-m-series.pkr.hcl

# NetBSD
packer build netbsd-arm64.pkr.hcl

# OpenBSD
packer build openbsd-arm64.pkr.hcl
```

### With Common Variables
```bash
packer build -var-file=common-m-series.pkrvars.hcl alpine-m-series.pkr.hcl
```

## Output

All builds produce qcow2 images in `output-<platform>-m-series/`:

- `output-alpine-m-series/alpine-m-series.qcow2`
- `output-freebsd-m-series/freebsd-m-series.qcow2`
- `output-netbsd-arm64/netbsd-m-series.qcow2`
- `output-openbsd-arm64/openbsd-m-series.qcow2`

## Common Provisioning Steps

All builds:
1. Install base packages
2. Configure for M-series
3. Build optimized kernel
4. Install kernel
5. Configure ZFS (except OpenBSD)
6. Create bootable image

## Platform Notes

### Alpine
- Uses musl libc (not glibc)
- 16K page size for unified memory
- Smallest image (~500MB)

### FreeBSD
- Native ZFS (best ZFS support)
- Asymmetric scheduler for P+E cores
- Production-ready

### NetBSD
- pkgsrc for ZFS
- Experimental but working
- Good for embedded

### OpenBSD
- NO ZFS (license conflict)
- Security-focused
- Kernel optimizations only
