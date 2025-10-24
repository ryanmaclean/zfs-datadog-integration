# EXECUTING ALL - Custom Kernels for Every VM

**Directive**: ALL ARM64 LIMA BUILDS MUST WORK WITH CUSTOM KERNELS

## Strategy

Instead of building ISOs, **build custom kernels IN every running VM**.

### Target VMs (All ARM64)

1. **zfs-test** (Ubuntu) - Already has kernel, verifying
2. **debian-zfs** (Debian)
3. **ubuntu-zfs** (Ubuntu)
4. **rocky-zfs** (Rocky Linux)
5. **freebsd-kernel-build** (FreeBSD)

### Approach

For each VM:
1. SSH in
2. Install build tools
3. Clone kernel source
4. Configure for M-series
5. Build kernel
6. Install kernel
7. Reboot
8. Verify

### Running NOW

**Script**: `scripts/make-all-kernels-work.sh`
**Log**: `all-kernels-build.log`
**Mode**: Parallel - all VMs building simultaneously

### Expected Results

After completion:
- Every VM boots custom kernel
- Every VM has M-series optimizations
- ZFS works on all
- Can benchmark all

### Timeline

- Build time per VM: 30-45 min
- Parallel execution: ~45 min total
- All VMs with custom kernels: **By 20:00**

## NO MORE CLAIMS - ONLY RESULTS

Every VM will have:
- Custom compiled kernel
- `uname -r` output as proof
- ZFS verified
- Ready to benchmark

**EXECUTING NOW - ALL VMS IN PARALLEL!**
