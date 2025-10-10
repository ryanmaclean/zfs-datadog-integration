# Datadog Dashboard and Monitors

Pre-built Datadog dashboard and monitor templates for ZFS event monitoring.

## Contents

- **dashboard.json** - ZFS Health and Events dashboard
- **monitors.json** - Alert monitor templates

## Dashboard Installation

### Via Datadog UI

1. Log in to [Datadog](https://app.datadoghq.com)
2. Go to **Dashboards** → **New Dashboard**
3. Click the settings gear ⚙️ → **Import dashboard JSON**
4. Copy contents of `dashboard.json` and paste
5. Click **Import**

### Via API

```bash
# Set your API and APP keys
export DD_API_KEY="your_api_key"
export DD_APP_KEY="your_app_key"
export DD_SITE="datadoghq.com"  # or datadoghq.eu, etc.

# Import dashboard
curl -X POST "https://api.${DD_SITE}/api/v1/dashboard" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -H "Content-Type: application/json" \
  -d @dashboard.json
```

### Via Terraform

```hcl
resource "datadog_dashboard_json" "zfs_health" {
  dashboard = file("${path.module}/datadog/dashboard.json")
}
```

## Dashboard Widgets

The dashboard includes:

1. **Recent ZFS Events** - Live event stream
2. **ZFS Events by Type** - Top event types (last 24h)
3. **ZFS Events Timeline** - Event count over time
4. **Scrub Events** - Scrub completion timeline
5. **Resilver Events** - Resilver completion timeline
6. **Pool State Changes** - Pool health state changes
7. **Checksum Errors** - Data integrity issues
8. **I/O Errors** - Hardware I/O problems
9. **Events by Host** - Most active hosts
10. **Events by Pool** - Most active pools

### Template Variables

- **host** - Filter by hostname
- **pool** - Filter by pool name

## Monitor Installation

### Via Datadog UI

For each monitor in `monitors.json`:

1. Go to **Monitors** → **New Monitor**
2. Choose **Event** monitor type
3. Copy the configuration from the JSON
4. Customize notification channels (replace `@pagerduty-zfs`, `@slack-ops` with your integrations)
5. Save the monitor

### Via API

```bash
# Import all monitors
for monitor in $(cat monitors.json | jq -c '.[]'); do
  curl -X POST "https://api.${DD_SITE}/api/v1/monitor" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
    -H "Content-Type: application/json" \
    -d "$monitor"
done
```

### Via Terraform

```hcl
resource "datadog_monitor" "zfs_pool_degraded" {
  name    = "ZFS Pool Degraded State"
  type    = "event alert"
  query   = "events('source:zfs priority:normal tags:(event_type:statechange AND pool_health:DEGRADED)').rollup('count').last('5m') > 0"
  message = file("${path.module}/datadog/monitor_messages/pool_degraded.txt")
  
  tags = ["service:zfs", "alert_type:pool_health"]
  
  monitor_thresholds {
    critical = 0
  }
}
```

## Monitors Included

### Critical Alerts

1. **ZFS Pool Failed State** (Priority 1)
   - Triggers: Pool enters FAULTED state
   - Action: Immediate response required

2. **ZFS Resilver Failed** (Priority 1)
   - Triggers: Resilver operation fails
   - Action: Pool redundancy at risk

### High Priority Alerts

3. **ZFS Pool Degraded State** (Priority 2)
   - Triggers: Pool enters DEGRADED state
   - Action: Investigate and replace failed devices

4. **ZFS Checksum Errors** (Priority 2)
   - Triggers: >2 checksum errors in 15 minutes
   - Thresholds: Warning at 2, Critical at 10
   - Action: Data corruption detected

5. **ZFS I/O Errors** (Priority 2)
   - Triggers: >5 I/O errors in 15 minutes
   - Thresholds: Warning at 5, Critical at 20
   - Action: Potential disk failure

### Medium Priority Alerts

6. **ZFS Scrub Failed** (Priority 3)
   - Triggers: Scrub operation fails
   - Action: Investigate and retry

7. **No ZFS Events Received** (Priority 3)
   - Triggers: No events for 24 hours
   - Action: Monitoring may be broken

## Customization

### Notification Channels

Replace placeholder notification channels in `monitors.json`:

- `@pagerduty-zfs` → Your PagerDuty integration
- `@pagerduty-critical` → Critical PagerDuty escalation
- `@slack-ops` → Your Slack channel
- `@slack-ops-critical` → Critical Slack channel

### Thresholds

Adjust alert thresholds based on your environment:

```json
"thresholds": {
  "critical": 10,  // Adjust as needed
  "warning": 2     // Adjust as needed
}
```

### Alert Priorities

Datadog priorities (1-5):
- **P1**: Critical - immediate action required
- **P2**: High - investigate soon
- **P3**: Medium - normal response time
- **P4**: Low - informational
- **P5**: Informational only

## Event Queries

Common Datadog event queries for ZFS:

```
# All ZFS events
source:zfs

# Scrub completions
source:zfs tags:event_type:scrub_finish

# Failed events
source:zfs tags:status:failed

# Specific pool
source:zfs pool:tank

# Specific host
source:zfs host:my-server

# Degraded pools
source:zfs tags:pool_health:DEGRADED

# Errors only
source:zfs tags:(event_type:checksum_error OR event_type:io_error)
```

## Tagging Strategy

Events are tagged with:

- `source:zfs` - All ZFS events
- `event_type:<type>` - Event type (scrub_finish, resilver_finish, etc.)
- `pool:<name>` - Pool name
- `host:<name>` - Hostname
- `pool_health:<state>` - Pool state (ONLINE, DEGRADED, FAULTED)
- `status:<status>` - Operation status (success, failed)
- `env:<environment>` - Environment (from config.sh)
- `service:zfs` - Service tag

## Best Practices

1. **Start with warning thresholds** - Adjust based on your environment
2. **Test notifications** - Ensure alerts reach the right people
3. **Document runbooks** - Include clear action steps in alert messages
4. **Review regularly** - Adjust thresholds based on false positive rate
5. **Use template variables** - Filter dashboard by host/pool
6. **Set up SLOs** - Track ZFS uptime and reliability

## Troubleshooting

### No data in dashboard

- Verify events are being sent: Check [Event Explorer](https://app.datadoghq.com/event/explorer)
- Search for `source:zfs`
- Run validation: `sudo ./scripts/validate-config.sh`

### Monitors not triggering

- Check monitor status in Datadog UI
- Verify event queries match your tag structure
- Test with manual events: `zpool scrub <pool>`

### False positives

- Adjust thresholds in monitor configuration
- Add exclusion tags if needed
- Increase evaluation windows

## Additional Resources

- [Datadog Events API](https://docs.datadoghq.com/api/latest/events/)
- [Datadog Dashboards](https://docs.datadoghq.com/dashboards/)
- [Datadog Monitors](https://docs.datadoghq.com/monitors/)
- [Event Monitor Documentation](https://docs.datadoghq.com/monitors/types/event/)

## Support

For issues with the integration:
- [GitHub Issues](https://github.com/ryanmaclean/zfs-datadog-integration/issues)
- [Installation Guide](../INSTALL.md)
- [Test Coverage](../docs/TEST-COVERAGE.md)
