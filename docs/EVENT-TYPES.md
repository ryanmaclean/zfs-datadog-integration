# ZFS Event Types

Complete list of ZFS events monitored by the Datadog integration.

## Currently Implemented

### Core Events (Tested)

| Event | Script | Priority | Description |
|-------|--------|----------|-------------|
| **scrub_finish** | scrub_finish-datadog.sh | Normal | Pool scrub completed |
| **resilver_finish** | resilver_finish-datadog.sh | Normal | Device resilver completed |
| **statechange** | statechange-datadog.sh | Normal-High | Pool health state changed |

### Error Events (Script Provided)

| Event | Script | Priority | Description |
|-------|--------|----------|-------------|
| **checksum** | checksum-error.sh | High | Checksum error detected (data corruption) |
| **io** | io-error.sh | High | I/O error detected (hardware issue) |

*Note: Requires zinject for testing. See [compile-zinject.sh](../scripts/compile-zinject.sh)*

### Lifecycle Events (New)

| Event | Script | Priority | Description |
|-------|--------|----------|-------------|
| **pool_destroy** | pool_destroy-datadog.sh | Normal | Pool has been destroyed |
| **pool_import** | pool_import-datadog.sh | Low | Pool has been imported |

### Device Events (New)

| Event | Script | Priority | Description |
|-------|--------|----------|-------------|
| **vdev_attach** | vdev_attach-datadog.sh | Normal | Device attached (mirror expansion) |
| **vdev_remove** | vdev_remove-datadog.sh | Normal | Device removed from pool |

### Configuration Events (New)

| Event | Script | Priority | Description |
|-------|--------|----------|-------------|
| **config_sync** | config_sync-datadog.sh | Low | Pool configuration synchronized |

## Event Coverage

**Current**: 10 event types
- ✅ Tested: 3 (scrub, resilver, statechange)
- 🔶 Needs testing: 7 (errors, lifecycle, devices, config)

**Event Coverage**: ~70% of common ZFS events

## Additional Events (Future)

These events could be added in future releases:

### Snapshot Events
- `snapshot_create` - Snapshot created
- `snapshot_destroy` - Snapshot destroyed
- `snapshot_rename` - Snapshot renamed

### Volume Events
- `zvol_create` - Volume created
- `zvol_destroy` - Volume destroyed

### Performance Events
- `trim_start` - TRIM operation started
- `trim_finish` - TRIM operation completed
- `trim_cancel` - TRIM operation cancelled

### Advanced Error Events
- `data_error` - Data error detected
- `device_offline` - Device went offline
- `device_degraded` - Device degraded

### Spare Events
- `spare_add` - Hot spare added
- `spare_remove` - Hot spare removed
- `spare_activate` - Hot spare activated

### Export/History
- `pool_export` - Pool exported
- `history_event` - ZFS history event

## Event Details

### scrub_finish

**When**: After scheduled or manual scrub completes
**Frequency**: Weekly (typical) or on-demand
**Data Includes**:
- Pool name
- Start/end time
- Bytes scanned
- Errors found (if any)
- Duration

**Use Case**: Monitor data integrity checks

### resilver_finish

**When**: After device replacement or mirror expansion
**Frequency**: Rare (only when devices change)
**Data Includes**:
- Pool name
- Bytes resilvered
- Duration
- Success/failure status

**Use Case**: Track recovery operations

### statechange

**When**: Pool health status changes
**Frequency**: Rare (only when problems occur)
**Possible States**:
- ONLINE → DEGRADED (device failure)
- DEGRADED → FAULTED (multiple failures)
- DEGRADED → ONLINE (recovery)

**Use Case**: Critical alerting for pool health

### checksum / io

**When**: Data corruption or I/O failures detected
**Frequency**: Should be rare (indicates hardware problems)
**Data Includes**:
- Pool name
- Device affected
- Error count

**Use Case**: Early warning for hardware failure

### pool_import / pool_destroy

**When**: Pool lifecycle management
**Frequency**: Administrative operations
**Use Case**: Audit trail for infrastructure changes

### vdev_attach / vdev_remove

**When**: Pool topology changes
**Frequency**: Capacity/redundancy changes
**Use Case**: Track storage expansion/reduction

### config_sync

**When**: Pool configuration written to disk
**Frequency**: Regular (after any pool changes)
**Use Case**: Track configuration updates (low priority)

## Event Priority Levels

| Priority | Alert Level | Use Case | Examples |
|----------|-------------|----------|----------|
| **Critical** | P1 | Immediate action | Pool FAULTED, Data loss imminent |
| **High** | P2 | Urgent attention | Pool DEGRADED, Errors detected |
| **Normal** | P3 | Standard monitoring | Scrub/resilver complete |
| **Low** | P4 | Informational | Pool import, Config sync |

## Datadog Event Properties

All events include:

```json
{
  "title": "Event title",
  "text": "Event description",
  "alert_type": "info|warning|error|success",
  "priority": "low|normal",
  "tags": [
    "source:zfs",
    "event_type:<type>",
    "pool:<pool_name>",
    "host:<hostname>",
    "env:<environment>",
    "service:zfs"
  ]
}
```

## Testing Events

### Trigger scrub
```bash
sudo zpool scrub <pool>
```

### Trigger resilver
```bash
# Add mirror to existing vdev
sudo zpool attach <pool> <existing_device> <new_device>
```

### Trigger pool import
```bash
sudo zpool export <pool>
sudo zpool import <pool>
```

### Trigger checksum error (requires zinject)
```bash
# Compile zinject first
sudo ./scripts/compile-zinject.sh

# Inject error
sudo ./scripts/checksum-error.sh <pool>
```

## Event Filtering

### In config.sh

Enable/disable specific event types:

```sh
MONITOR_SCRUB="true"
MONITOR_RESILVER="true"
MONITOR_POOL_HEALTH="true"
MONITOR_CHECKSUM_ERRORS="true"
MONITOR_IO_ERRORS="true"
```

### In Datadog

Filter events by tags:

```
source:zfs event_type:scrub_finish
source:zfs alert_type:error
source:zfs pool:tank host:server1
```

## Adding Custom Events

To add a new event type:

1. Create script: `scripts/newevent-datadog.sh`
2. Follow existing pattern:
```sh
#!/bin/sh
ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1
. "${ZED_DIR}/config.sh" || exit 1

EVENT_TYPE="newevent"
TITLE="Your Event Title"
TEXT="Event description with ${ZEVENT_POOL}"
ALERT_TYPE="info"
PRIORITY="normal"

send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$PRIORITY" "$EVENT_TYPE"
```
3. Make executable: `chmod +x scripts/newevent-datadog.sh`
4. Deploy: `sudo cp scripts/newevent-datadog.sh /etc/zfs/zed.d/`
5. Test: Trigger the event

## Resources

- [ZFS Event Daemon (ZED) Documentation](https://openzfs.github.io/openzfs-docs/man/8/zed.8.html)
- [ZFS Events Reference](https://github.com/openzfs/zfs/tree/master/cmd/zed/zed.d)
- [Datadog Events API](https://docs.datadoghq.com/api/latest/events/)

## Support

Questions about events? Open an issue:
- [GitHub Issues](https://github.com/ryanmaclean/zfs-datadog-integration/issues)
