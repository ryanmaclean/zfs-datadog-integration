# ZFS Datadog Integration - Testing Guide

## Quick Start Testing

### Automated E2E Test
```bash
./e2e-test.sh
```

This will:
1. Create Lima VM with Ubuntu 24.04 ARM64
2. Install OpenZFS 2.2.2
3. Create test ZFS pool
4. Start mock Datadog server
5. Install zedlets
6. Run automated tests
7. Validate events and metrics

### Manual Testing in VM

```bash
# Start VM (if not already running)
limactl start --name=zfs-test lima-zfs.yaml

# Shell into VM
limactl shell zfs-test

# Run tests
sudo zpool scrub testpool
curl http://localhost:8080/status | jq '.'
```

## File Naming Conventions

The zedlets follow ZFS event naming conventions for automatic triggering:

| Zedlet File | ZFS Event | Description |
|-------------|-----------|-------------|
| `scrub_finish-datadog.sh` | `scrub_finish` | Triggered when scrub completes |
| `resilver_finish-datadog.sh` | `resilver_finish` | Triggered when resilver completes |
| `statechange-datadog.sh` | `statechange` | Triggered on pool state changes |
| `all-datadog.sh` | All events | Routes checksum/io errors |

**Important**: The underscore in `scrub_finish` and `resilver_finish` matches ZFS event naming. The dash after the event name (e.g., `-datadog`) is the script identifier.

## Test Results

### Successful Test Output
```json
{
  "events_received": 2,
  "metrics_received": 2,
  "latest_event": "ZFS Scrub Completed: testpool"
}
```

### Expected Events
- **Title**: "ZFS Scrub Completed: testpool"
- **Alert Type**: "success" (0 errors) or "error" (with errors)
- **Tags**: pool, host, env, service
- **Metrics**: `zfs.scrub.errors`, `zfs.scrub.duration`

## VM Management

```bash
# List VMs
limactl list

# Stop VM
limactl stop zfs-test

# Delete VM
limactl delete zfs-test

# View VM logs
limactl shell zfs-test sudo journalctl -u zfs-zed -f
```

## Mock Datadog Server

The mock server captures both:
- **HTTP Events** (port 8080): Datadog Events API calls
- **UDP Metrics** (port 8125): DogStatsD metrics

View captured data:
```bash
curl http://localhost:8080/status | jq '.'
```

## Troubleshooting

### No events captured
1. Check ZED is running: `systemctl status zfs-zed`
2. Check zedlet permissions: `ls -la /etc/zfs/zed.d/*datadog*.sh`
3. Check ZED logs: `journalctl -u zfs-zed -n 50`
4. Verify mock server: `ps aux | grep mock-datadog`

### Zedlets not triggering
1. Verify correct naming (underscore, not dash)
2. Check files are executable: `chmod 755 /etc/zfs/zed.d/*datadog*.sh`
3. Restart ZED: `systemctl restart zfs-zed`

## Repeatable Process

The solution is now fully automated:
1. ✅ Correct ZFS event naming conventions
2. ✅ No manual symlinks required
3. ✅ Automated installation via `install.sh`
4. ✅ Automated testing via `e2e-test.sh`
5. ✅ Works out of the box in fresh environments

## Next Steps

For production deployment:
1. Replace mock server with real Datadog API key
2. Ensure Datadog Agent is running
3. Run `./install.sh` on production systems
4. Monitor events in Datadog dashboard
