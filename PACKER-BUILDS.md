# PACKER AUTOMATED BUILDS - No More Manual!

**Using Packer to automate NetBSD and OpenBSD installations**

## NetBSD ARM64 - BUILDING NOW ✅

**File**: `packer/netbsd-arm64.pkr.hcl`
**Status**: Automated installation running
**Log**: `netbsd-packer.log`

**Automation**:
- Downloads NetBSD 10.0 ARM64 ISO
- Automated installer keystrokes
- Configures network (DHCP)
- Sets root password
- Enables sshd
- Installs to disk
- Reboots
- Builds M-series kernel
- Outputs: `output-netbsd-arm64/netbsd-m-series.qcow2`

## OpenBSD ARM64 - BUILDING NOW ✅

**File**: `packer/openbsd-arm64.pkr.hcl`
**Status**: Automated installation running
**Log**: `openbsd-packer.log`

**Automation**:
- Downloads OpenBSD 7.6 ARM64 ISO
- Automated installer keystrokes
- Configures network (DHCP)
- Sets root password
- Partitions disk automatically
- Installs base system
- Reboots
- Builds M-series kernel (no ZFS - license conflict)
- Outputs: `output-openbsd-arm64/openbsd-m-series.qcow2`

## Packer Advantages

✅ **No manual intervention** - Full automation
✅ **Reproducible** - Same config = same image
✅ **Version controlled** - .pkr.hcl in git
✅ **Fast** - Parallel builds
✅ **Outputs qcow2** - Ready for Lima

## Boot Commands

### NetBSD
```
1 - Install NetBSD
a - English
a - Keyboard
a - Hard disk
b - Entire disk
... (automated)
```

### OpenBSD
```
i - Install
hostname: openbsd-m-series
vio0 - Network
dhcp - DHCP
... (automated)
```

## After Packer Completes

Images ready at:
- `packer/output-netbsd-arm64/netbsd-m-series.qcow2`
- `packer/output-openbsd-arm64/openbsd-m-series.qcow2`

Use with Lima:
```bash
limactl start --name=netbsd-m netbsd-m-series.qcow2
limactl start --name=openbsd-m openbsd-m-series.qcow2
```

## Timeline

- NetBSD: ~40 minutes (install + kernel build)
- OpenBSD: ~30 minutes (install + kernel build)

Both building in parallel!

**NO MORE MANUAL INSTALLS - PACKER AUTOMATES EVERYTHING!** ✅
