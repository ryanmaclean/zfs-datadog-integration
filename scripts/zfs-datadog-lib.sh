#!/bin/sh
#
# ZFS Datadog Integration Library
# Common functions for sending ZFS events and metrics to Datadog
# POSIX-compatible for BSD/FreeBSD/TrueNAS
#

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
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
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" >&2
}

# Send event to Datadog Events API
# Usage: send_datadog_event "title" "text" "alert_type" "tags"
send_datadog_event() {
    local title="$1"
    local text="$2"
    local alert_type="${3:-info}"  # info, warning, error, success
    local tags="${4:-$DD_TAGS}"
    
    if [ -z "$DD_API_KEY" ]; then
        log_message "ERROR" "DD_API_KEY not set, cannot send event"
        return 1
    fi
    
    local timestamp=$(date +%s)
    local tag_array=""
    
    # Convert comma-separated tags to JSON array
    if [ -n "$tags" ]; then
        tag_array="["
        first=1
        OLD_IFS="$IFS"
        IFS=','
        for tag in $tags; do
            if [ $first -eq 1 ]; then
                tag_array="${tag_array}\"${tag}\""
                first=0
            else
                tag_array="${tag_array},\"${tag}\""
            fi
        done
        tag_array="${tag_array}]"
        IFS="$OLD_IFS"
    else
        tag_array="[]"
    fi
    
    local json_payload=$(cat <<EOF
{
  "title": "$title",
  "text": "$text",
  "priority": "normal",
  "tags": $tag_array,
  "alert_type": "$alert_type",
  "source_type_name": "zfs",
  "host": "$HOSTNAME"
}
EOF
)
    
    # Retry logic with exponential backoff
    local max_retries=3
    local retry=0
    local wait_time=1
    local response
    local exit_code
    
    while [ $retry -lt $max_retries ]; do
        response=$(curl -s -m 10 -X POST "${DD_API_URL}/api/v1/events" \
            -H "Content-Type: application/json" \
            -H "DD-API-KEY: ${DD_API_KEY}" \
            -d "$json_payload" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            log_message "INFO" "Event sent to Datadog: $title"
            return 0
        fi
        
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            log_message "WARN" "Failed to send event (attempt $retry/$max_retries), retrying in ${wait_time}s..."
            sleep $wait_time
            wait_time=$((wait_time * 2))
        fi
    done
    
    log_message "ERROR" "Failed to send event after $max_retries attempts: $response"
    return 1
}

# Send metric to DogStatsD
# Usage: send_metric "metric.name" "value" "type" "tags"
# Types: gauge, counter, histogram, distribution
send_metric() {
    local metric_name="$1"
    local value="$2"
    local metric_type="${3:-gauge}"
    local tags="${4:-$DD_TAGS}"
    
    # Add hostname tag
    if [ -n "$tags" ]; then
        tags="${tags},host:${HOSTNAME}"
    else
        tags="host:${HOSTNAME}"
    fi
    
    local statsd_message="${metric_name}:${value}|${metric_type:0:1}|#${tags}"
    
    # Send via UDP to DogStatsD with retry
    local max_retries=2
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        printf "%s" "$statsd_message" | nc -u -w1 "$DOGSTATSD_HOST" "$DOGSTATSD_PORT" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log_message "DEBUG" "Metric sent: $statsd_message"
            return 0
        fi
        
        retry=$((retry + 1))
        [ $retry -lt $max_retries ] && sleep 1
    done
    
    log_message "ERROR" "Failed to send metric after $max_retries attempts: $statsd_message"
    return 1
}

# Get pool health status as numeric value
# 0=online, 1=degraded, 2=faulted, 3=offline, 4=unavail, 5=removed
get_pool_health_value() {
    local state="$1"
    # Convert to lowercase using tr
    state=$(printf "%s" "$state" | tr '[:upper:]' '[:lower:]')
    case "$state" in
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
    local state="$1"
    # Convert to lowercase using tr
    state=$(printf "%s" "$state" | tr '[:upper:]' '[:lower:]')
    case "$state" in
        online) echo "success" ;;
        degraded) echo "warning" ;;
        faulted|offline|unavail) echo "error" ;;
        *) echo "info" ;;
    esac
}

# Build tags from ZFS event environment variables
build_tags() {
    local base_tags="$DD_TAGS"
    local pool="${ZEVENT_POOL:-unknown}"
    local vdev="${ZEVENT_VDEV_PATH:-}"
    
    local tags="$base_tags,pool:${pool}"
    
    if [ -n "$vdev" ]; then
        # Extract device name from path
        local vdev_name=$(basename "$vdev")
        tags="${tags},vdev:${vdev_name}"
    fi
    
    if [ -n "${ZEVENT_VDEV_STATE}" ]; then
        tags="${tags},vdev_state:${ZEVENT_VDEV_STATE}"
    fi
    
    echo "$tags"
}

# Functions are sourced, no need to export in POSIX sh
