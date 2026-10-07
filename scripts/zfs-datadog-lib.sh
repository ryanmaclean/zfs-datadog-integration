#!/bin/sh
#
# ZFS Datadog Integration Library
# Common functions for sending ZFS events and metrics to Datadog
# POSIX-compatible for BSD/FreeBSD/TrueNAS
#
# Strictly POSIX: no local. Function-scoped variables use a per-function
# prefix (_lm_, _ev_, _sm_, _ph_, _at_, _bt_) so they cannot collide with
# the sourcing zedlet's variables or with each other across nested calls.

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [ -f "$CONFIG_FILE" ]; then
    . "${SCRIPT_DIR}/config.sh"
fi

# Configuration with defaults
DD_API_KEY="${DD_API_KEY:-${DATADOG_API_KEY}}"
DD_SITE="${DD_SITE:-datadoghq.com}"
DD_API_URL="${DD_API_URL:-https://api.${DD_SITE}}"
DOGSTATSD_HOST="${DOGSTATSD_HOST:-localhost}"
DOGSTATSD_PORT="${DOGSTATSD_PORT:-8125}"
DD_TAGS="${DD_TAGS:-env:production}"
HOSTNAME="${HOSTNAME:-$(hostname)}"

# Logging function
log_message() {
    _lm_level="$1"
    _lm_message="$2"
    _lm_timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$_lm_timestamp] [$_lm_level] $_lm_message" >&2
    if command -v logger >/dev/null 2>&1; then
        logger -t zfs-datadog "[$_lm_level] $_lm_message"
    fi
}

# Send event to Datadog Events API
# Usage: send_datadog_event "title" "text" "alert_type" "tags" "priority" "event_type"
#
#   title       required
#   text        required
#   alert_type  info | warning | error | success   (default: info)
#   tags        comma-separated                    (default: $DD_TAGS)
#   priority    normal | low                       (default: normal)
#   event_type  ZFS event class, e.g. pool_import  (optional; added as a tag)
#
# tags stays in position 4 so existing four-argument callers are unaffected.
send_datadog_event() {
    _ev_title="$1"
    _ev_text="$2"
    _ev_alert_type="${3:-info}"  # info, warning, error, success
    _ev_tags="${4:-$DD_TAGS}"
    _ev_priority="${5:-normal}"
    _ev_event_type="${6:-}"

    if [ -z "$DD_API_KEY" ]; then
        log_message "ERROR" "DD_API_KEY not set, cannot send event"
        return 1
    fi

    # The Events API accepts only "normal" and "low".
    case "$_ev_priority" in
        normal|low) ;;
        *)
            log_message "WARN" "Unknown priority '$_ev_priority', falling back to normal"
            _ev_priority="normal"
            ;;
    esac

    # Surface the ZFS event class as a tag so it is queryable in Datadog.
    if [ -n "$_ev_event_type" ]; then
        if [ -n "$_ev_tags" ]; then
            _ev_tags="${_ev_tags},event_type:${_ev_event_type}"
        else
            _ev_tags="event_type:${_ev_event_type}"
        fi
    fi
    _ev_tag_array=""

    # Convert comma-separated tags to JSON array
    if [ -n "$_ev_tags" ]; then
        _ev_tag_array="["
        _ev_first=1
        _ev_old_ifs="$IFS"
        IFS=','
        for _ev_tag in $_ev_tags; do
            if [ $_ev_first -eq 1 ]; then
                _ev_tag_array="${_ev_tag_array}\"${_ev_tag}\""
                _ev_first=0
            else
                _ev_tag_array="${_ev_tag_array},\"${_ev_tag}\""
            fi
        done
        _ev_tag_array="${_ev_tag_array}]"
        IFS="$_ev_old_ifs"
    else
        _ev_tag_array="[]"
    fi

    _ev_json_payload=$(cat <<EOF2
{
  "title": "$_ev_title",
  "text": "$_ev_text",
  "priority": "$_ev_priority",
  "tags": $_ev_tag_array,
  "alert_type": "$_ev_alert_type",
  "source_type_name": "zfs",
  "host": "$HOSTNAME"
}
EOF2
)

    # Retry logic with exponential backoff
    _ev_max_retries=3
    _ev_retry=0
    _ev_wait_time=1
    _ev_response=

    while [ $_ev_retry -lt $_ev_max_retries ]; do
        if _ev_response=$(curl -s -m 10 -X POST "${DD_API_URL}/api/v1/events" \
            -H "Content-Type: application/json" \
            -H "DD-API-KEY: ${DD_API_KEY}" \
            -d "$_ev_json_payload" 2>&1); then
            log_message "INFO" "Event sent to Datadog: $_ev_title"
            return 0
        fi

        _ev_retry=$((_ev_retry + 1))
        if [ $_ev_retry -lt $_ev_max_retries ]; then
            log_message "WARN" "Failed to send event (attempt $_ev_retry/$_ev_max_retries), retrying in ${_ev_wait_time}s..."
            sleep $_ev_wait_time
            _ev_wait_time=$((_ev_wait_time * 2))
        fi
    done

    log_message "ERROR" "Failed to send event after $_ev_max_retries attempts: $_ev_response"
    return 1
}

# Send metric to DogStatsD
# Usage: send_metric "metric.name" "value" "type" "tags"
# Types: gauge, counter, histogram, distribution
send_metric() {
    _sm_metric_name="$1"
    _sm_value="$2"
    _sm_metric_type="${3:-gauge}"
    _sm_tags="${4:-$DD_TAGS}"

    # Add hostname tag
    if [ -n "$_sm_tags" ]; then
        _sm_tags="${_sm_tags},host:${HOSTNAME}"
    else
        _sm_tags="host:${HOSTNAME}"
    fi

    # Extract first character of metric type in a POSIX-friendly way (gauge -> g, counter -> c, etc.)
    _sm_metric_short=$(printf '%s' "$_sm_metric_type" | cut -c1)
    _sm_statsd_message="${_sm_metric_name}:${_sm_value}|${_sm_metric_short}|#${_sm_tags}"

    # Send via UDP to DogStatsD with retry
    _sm_max_retries=2
    _sm_retry=0

    while [ $_sm_retry -lt $_sm_max_retries ]; do
        if printf '%s' "$_sm_statsd_message" | nc -u -w1 "$DOGSTATSD_HOST" "$DOGSTATSD_PORT" 2>/dev/null; then
            log_message "DEBUG" "Metric sent: $_sm_statsd_message"
            return 0
        fi

        _sm_retry=$((_sm_retry + 1))
        [ $_sm_retry -lt $_sm_max_retries ] && sleep 1
    done

    log_message "ERROR" "Failed to send metric after $_sm_max_retries attempts: $_sm_statsd_message"
    return 1
}

# Get pool health status as numeric value
# 0=online, 1=degraded, 2=faulted, 3=offline, 4=unavail, 5=removed
get_pool_health_value() {
    _ph_state="$1"
    # Convert to lowercase using tr
    _ph_state=$(printf "%s" "$_ph_state" | tr '[:upper:]' '[:lower:]')
    case "$_ph_state" in
        online) echo 0 ;;
        degraded) echo 1 ;;
        faulted) echo 2 ;;
        offline) echo 3 ;;
        unavail) echo 4 ;;
        removed) echo 5 ;;
        *) echo 99 ;;
    esac
}

# Get alert type based on pool state
get_alert_type() {
    _at_state="$1"
    # Convert to lowercase using tr
    _at_state=$(printf "%s" "$_at_state" | tr '[:upper:]' '[:lower:]')
    case "$_at_state" in
        online) echo "success" ;;
        degraded) echo "warning" ;;
        faulted|offline|unavail) echo "error" ;;
        *) echo "info" ;;
    esac
}

# Build tags from ZFS event environment variables
build_tags() {
    _bt_base_tags="$DD_TAGS"
    _bt_pool="${ZEVENT_POOL:-unknown}"
    _bt_vdev="${ZEVENT_VDEV_PATH:-}"

    _bt_tags="$_bt_base_tags,pool:${_bt_pool}"

    if [ -n "$_bt_vdev" ]; then
        # Extract device name from path
        _bt_vdev_name=$(basename "$_bt_vdev")
        _bt_tags="${_bt_tags},vdev:${_bt_vdev_name}"
    fi

    if [ -n "${ZEVENT_VDEV_STATE}" ]; then
        _bt_tags="${_bt_tags},vdev_state:${ZEVENT_VDEV_STATE}"
    fi

    echo "$_bt_tags"
}

# Functions are sourced, no need to export in POSIX sh
