# Packer Automation Strategy

## What's Automated

### ✅ Build Process (Fully Automated)
**9 Packer templates** running in parallel:
- Download OS images/ISOs
- Boot VMs with KVM acceleration
- Cloud-init configuration (Ubuntu, Debian, Arch, Rocky, Fedora)
- Boot commands via VNC (FreeBSD, OpenBSD, NetBSD, OpenIndiana)
- SSH connection and provisioning
- Install ZFS packages
- Install Datadog Agent with API key
- Deploy zedlets to `/etc/zfs/zed.d/` or `/usr/local/etc/zfs/zed.d/`
- Configure permissions and restart services
- Create qcow2 images
- Shutdown and package

**Parallel execution**: All 9 OSes building simultaneously on i9-zfs-pop

### ✅ Monitoring (Automated)
- Datadog Agent on build host (i9-zfs-pop)
- Build logs streaming to Datadog
- Background status checks every 10 minutes
- Process monitoring

### ⏳ Testing (Needs Automation)
**Currently manual**, needs script:
1. Boot each built image
2. SSH and verify:
   - ZFS installed (`zpool list`)
   - Datadog Agent running
   - Zedlets present in `/etc/zfs/zed.d/`
3. Create test pool (mirror with 2x 256MB files)
4. Run scrub
5. Verify Datadog event sent
6. Cleanup

**Script exists**: `test-all-packer-images.sh` (created earlier)
**Status**: Not executed yet (waiting for builds to complete)

## What's NOT Automated

### ❌ Image Testing
- Booting built images
- Creating test pools
- Running scrubs
- Verifying Datadog events

### ❌ Results Validation
- Checking all 9 OSes passed tests
- Collecting metrics
- Final report generation

## Timeline

**Current** (23:01):
- 9 Packer builds running (started 22:52)
- ~9 minutes elapsed
- Waiting for SSH connections and provisioning
- Estimated 10-20 more minutes

**Next** (23:10-23:30):
- Builds complete
- Run automated test script
- Verify all 9 OSes

## Full Automation Path

To make this 100% automated:

```bash
# 1. Build all images (DONE - running now)
cd /tank3/vms && ./build-all-packer.sh

# 2. Wait for completion (AUTOMATED - background check running)
# Background process checks every 10 min

# 3. Test all images (READY - script exists)
./test-all-packer-images.sh

# 4. Verify Datadog events (NEEDS SCRIPT)
./verify-datadog-events.sh

# 5. Generate report (NEEDS SCRIPT)
./generate-final-report.sh
```

## Current Status

**Automated**: Build process (9 OSes in parallel)
**Semi-automated**: Monitoring (background checks)
**Manual**: Testing and validation (scripts exist but not executed)

**Total automation**: ~70%
**Remaining**: Execute test scripts once builds complete
