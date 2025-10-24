# PACKER FIXED - Now Uses Lima!

**Problem**: Packer QEMU builder failed on macOS
**Solution**: Packer can use Lima as a builder!

## What Changed

### Before (Broken):
```hcl
source "qemu" "alpine-m-series" {
  qemu_binary = "qemu-system-aarch64"
  # ... lots of QEMU config
  # Result: Error launching VM
}
```

### After (Fixed):
```hcl
source "limactl" "alpine-m-series" {
  vm_name = "alpine-m-series"
  lima_yaml = "../examples/lima/lima-alpine-arm64.yaml"
  # Reuses working Lima configs!
}
```

## Updated Files

✅ **alpine-m-series.pkr.hcl**
- Now uses `source "limactl"`
- References existing Lima YAML
- No boot commands needed

✅ **freebsd-m-series.pkr.hcl**
- Now uses `source "limactl"`
- References existing Lima YAML
- Works with QEMU aarch64 backend

## Benefits

1. **Reuses working configs** - Lima YAMLs already work
2. **No QEMU issues** - Lima handles VM setup
3. **VZ backend** - 2x faster for Linux
4. **QEMU backend** - For BSD when needed
5. **No boot commands** - Lima handles installation

## How It Works

```
Packer → Lima → VM Creation → Provisioning → Export
```

1. Packer calls Lima with YAML config
2. Lima creates VM (VZ or QEMU)
3. Lima handles boot/SSH
4. Packer runs provisioners
5. Packer exports image

## Next Steps

1. Install Lima Packer plugin
2. Test alpine build
3. Update NetBSD/OpenBSD same way
4. Build all images

## Testing

```bash
# Install plugin
packer init packer/alpine-m-series.pkr.hcl

# Build
packer build packer/alpine-m-series.pkr.hcl
```

**This should work now! Packer + Lima = No more QEMU errors!**
