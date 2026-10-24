#!/bin/sh
#
# ZFS Datadog Integration Library
# Common functions for handing ZFS events and metrics to the local Agent
# POSIX-compatible for BSD/FreeBSD/TrueNAS
#
# Strictly POSIX: no local. Sending and validation functions run in subshells
# so their temporary variables cannot change the sourcing zedlet's state.

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [ -f "$CONFIG_FILE" ]; then
    . "${SCRIPT_DIR}/config.sh"
fi

# Configuration with defaults
DOGSTATSD_HOST="${DOGSTATSD_HOST:-127.0.0.1}"
DOGSTATSD_PORT="${DOGSTATSD_PORT:-8125}"
DD_TAGS="${DD_TAGS:-service:zfs}"
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

# Refuse nonlocal destinations and ambiguous port or tag values before a send.
# A successful UDP write means only that the local handoff was attempted; it
# does not prove Agent parsing or Datadog intake. Never retry a datagram here.
#
# Datagrams go out with nc -u -w0. With -w1 both FreeBSD nc and OpenBSD or
# Debian netcat-openbsd keep waiting one full second after stdin EOF for a
# UDP reply that never comes, so a three-datagram zedlet took about 3 s. -w0
# returns as soon as the datagram is written (checked against a local
# listener on FreeBSD 15.1 and 16.0 nc and netcat-openbsd 1.226; GNU
# netcat-traditional is untested). The exit status is unchanged: UDP never
# reports an absent receiver either way.
#
# -w0 also makes nc's first poll() non-blocking, and nc returns without
# sending when stdin is not readable yet. Fed from `printf | nc` that drops
# the datagram whenever nc polls before printf has written, which happened
# for 1 to 4 of 20 sends on a loaded FreeBSD 16 host. send_local_datagram
# therefore writes the datagram to a private mktemp file first: a regular
# file is always readable, so nc sees the whole datagram on its first poll.
valid_agent_endpoint() (
    [ "$DOGSTATSD_HOST" = 127.0.0.1 ] || return 1
    case "$DOGSTATSD_PORT" in ''|*[!0-9]*) return 1 ;; esac
    case "$DOGSTATSD_PORT" in 0?*) return 1 ;; esac
    [ "${#DOGSTATSD_PORT}" -le 5 ] || return 1
    [ "$DOGSTATSD_PORT" -ge 1 ] && [ "$DOGSTATSD_PORT" -le 65535 ]
)

# Hand one datagram to the loopback Agent. Usage: send_local_datagram "packet"
# The temporary file is created 0600 by mktemp and removed before returning.
send_local_datagram() (
    _ld_file=$(mktemp "${TMPDIR:-/tmp}/zfs-datadog.XXXXXX") || return 1
    if printf '%s' "$1" > "$_ld_file"; then
        nc -u -w0 "$DOGSTATSD_HOST" "$DOGSTATSD_PORT" < "$_ld_file" 2>/dev/null
        _ld_rc=$?
    else
        _ld_rc=1
    fi
    rm -f "$_ld_file"
    return "$_ld_rc"
)

valid_agent_tags() (
    case "$1" in
        '') return 0 ;;
        ,*|*,|*,,*|*[!A-Za-z0-9_.,:/-]*) return 1 ;;
    esac
    # The Agent, not a ZED tag, supplies the Datadog host identity.
    case ",$1," in *,host:*) return 1 ;; esac
    [ "${#1}" -le 512 ] || return 1
    return 0
)

valid_zfs_tag_value() (
    case "$1" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac
    [ "${#1}" -le 128 ]
)

valid_nonnegative_integer() (
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    case "$1" in 0?*) return 1 ;; esac
    [ "${#1}" -le 15 ]
)

# Send one DogStatsD event to the loopback Agent.
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
send_datadog_event() (
    LC_ALL=C
    export LC_ALL
    _ev_title=$1
    _ev_text=$2
    _ev_alert_type=${3:-info}
    _ev_tags=${4:-$DD_TAGS}
    _ev_priority=${5:-normal}
    _ev_event_type=${6:-}

    valid_agent_endpoint || { log_message ERROR 'Invalid local DogStatsD endpoint'; return 1; }
    case "$_ev_title$_ev_text" in *[![:print:]]*)
        log_message ERROR 'Event contains a control character'; return 1 ;;
    esac
    [ -n "$_ev_title" ] || { log_message ERROR 'Event title is empty'; return 1; }
    case "$_ev_title" in *'|'*)
        log_message ERROR 'Event title contains a wire delimiter'; return 1 ;;
    esac
    case "$_ev_alert_type" in info|warning|error|success) ;; *)
        log_message ERROR 'Invalid event alert type'; return 1 ;; esac
    case "$_ev_priority" in normal|low) ;; *)
        log_message ERROR 'Invalid event priority'; return 1 ;; esac
    valid_agent_tags "$_ev_tags" || { log_message ERROR 'Invalid event tags'; return 1; }
    if [ -n "$_ev_event_type" ]; then
        valid_zfs_tag_value "$_ev_event_type" || {
            log_message ERROR 'Invalid event type tag'; return 1;
        }
        if [ -n "$_ev_tags" ]; then
            _ev_tags="${_ev_tags},event_type:${_ev_event_type}"
        else
            _ev_tags="event_type:${_ev_event_type}"
        fi
    fi
    valid_agent_tags "$_ev_tags" || { log_message ERROR 'Invalid event tags'; return 1; }
    # Zedlets already use literal backslash-n in their text. The Agent parser
    # turns those sequences into newlines after the byte-length-framed parse.
    _ev_title_len=$(LC_ALL=C printf '%s' "$_ev_title" | wc -c) || return 1
    _ev_text_len=$(LC_ALL=C printf '%s' "$_ev_text" | wc -c) || return 1
    _ev_title_len=${_ev_title_len##* }
    _ev_text_len=${_ev_text_len##* }
    _ev_packet="_e{${_ev_title_len},${_ev_text_len}}:${_ev_title}|${_ev_text}|p:${_ev_priority}|t:${_ev_alert_type}|s:zfs"
    [ -z "$_ev_tags" ] || _ev_packet="${_ev_packet}|#${_ev_tags}"
    [ "${#_ev_packet}" -le 8192 ] || {
        log_message ERROR 'Event exceeds local datagram limit'; return 1;
    }
    if send_local_datagram "$_ev_packet"; then
        log_message INFO 'Event handed to local Agent socket'
        return 0
    fi
    log_message ERROR 'Local Agent event handoff failed'
    return 1
)

# Send metric to DogStatsD
# Usage: send_metric "metric.name" "value" "type" "tags"
# Types: gauge, counter, histogram, distribution
send_metric() (
    LC_ALL=C
    export LC_ALL
    _sm_metric_name=$1
    _sm_value=$2
    _sm_metric_type=${3:-gauge}
    _sm_tags=${4:-$DD_TAGS}

    valid_agent_endpoint || { log_message ERROR 'Invalid local DogStatsD endpoint'; return 1; }
    case "$_sm_metric_name" in ''|[!A-Za-z_]*|*[!A-Za-z0-9_.]*)
        log_message ERROR 'Invalid metric name'; return 1 ;; esac
    _sm_number=${_sm_value#-}
    case "$_sm_number" in ''|*[!0-9.]*)
        log_message ERROR 'Invalid metric value'; return 1 ;; esac
    case "$_sm_number" in
        *.*) case "$_sm_number" in *.*.*|.*|*.)
            log_message ERROR 'Invalid metric value'; return 1 ;; esac ;;
    esac
    case "$_sm_metric_type" in
        gauge) _sm_metric_short=g ;; counter) _sm_metric_short=c ;;
        histogram) _sm_metric_short=h ;; distribution) _sm_metric_short=d ;;
        *) log_message ERROR 'Invalid metric type'; return 1 ;;
    esac
    valid_agent_tags "$_sm_tags" || { log_message ERROR 'Invalid metric tags'; return 1; }
    _sm_packet="${_sm_metric_name}:${_sm_value}|${_sm_metric_short}"
    [ -z "$_sm_tags" ] || _sm_packet="${_sm_packet}|#${_sm_tags}"
    [ "${#_sm_packet}" -le 8192 ] || {
        log_message ERROR 'Metric exceeds local datagram limit'; return 1;
    }
    if send_local_datagram "$_sm_packet"; then
        log_message DEBUG 'Metric handed to local Agent socket'
        return 0
    fi
    log_message ERROR 'Local Agent metric handoff failed'
    return 1
)

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

# Readable vdev state for the current zevent.
# ZED exports the vdev_state nvpair as the numeric vdev_state_t value and adds
# the readable name as ZEVENT_VDEV_STATE_STR (cmd/zed/zed_event.c), so prefer
# the name and map a bare number (replayed or hand-built events) the same way
# zpool_state_to_name() does. Prints nothing when the event has no vdev state.
zevent_vdev_state() (
    _vs_state=${ZEVENT_VDEV_STATE_STR:-${ZEVENT_VDEV_STATE:-}}
    case "$_vs_state" in
        '') return 0 ;;
        *[!0-9]*) printf '%s\n' "$_vs_state" ;;
        1|2) echo OFFLINE ;;
        3) echo REMOVED ;;
        4) echo UNAVAIL ;;
        5) echo FAULTED ;;
        6) echo DEGRADED ;;
        7) echo ONLINE ;;
        *) echo UNKNOWN ;;
    esac
)

# Result of the finished scrub or resilver on a pool, as "errors seconds".
# Real scrub_finish and resilver_finish zevents carry only the pool name, GUID,
# state and history context: no error count and no start or end time. Like
# upstream scrub_finish-notify.sh, read the scan line of zpool status instead
# ("scrub repaired 0B in 00:00:01 with 0 errors on ...", or "N days HH:MM:SS"
# for long scans). Fails, printing nothing, unless that line describes a
# finished scan of the requested kind, so callers never report a guessed 0.
# Usage: zpool_scan_result pool scrub|resilver
zpool_scan_result() (
    _sr_pool=$1
    _sr_kind=$2
    valid_zfs_tag_value "$_sr_pool" || return 1
    case "$_sr_kind" in scrub|resilver) ;; *) return 1 ;; esac
    _sr_line=$(LC_ALL=C "${ZPOOL:-zpool}" status "$_sr_pool" 2>/dev/null |
        sed -n 's/^[[:space:]]*scan: //p') || return 1
    _sr_result=$(printf '%s\n' "$_sr_line" | awk -v kind="$_sr_kind" '
        NR > 1 { bad = 1; exit }
        {
            if (kind == "scrub") {
                if ($1 != "scrub" || $2 != "repaired") { bad = 1; exit }
                i = 4
            } else {
                if ($1 != "resilvered") { bad = 1; exit }
                i = 3
            }
            if ($i != "in") { bad = 1; exit }
            i++
            days = 0
            if ($(i + 1) == "days") {
                days = $i
                i += 2
            }
            if (split($i, t, ":") != 3) { bad = 1; exit }
            if ($(i + 1) != "with" || $(i + 3) != "errors" || $(i + 4) != "on") { bad = 1; exit }
            errors = $(i + 2)
            if (days !~ /^[0-9]+$/ || errors !~ /^[0-9]+$/) { bad = 1; exit }
            if (t[1] !~ /^[0-9]+$/ || t[2] !~ /^[0-9]+$/ || t[3] !~ /^[0-9]+$/) { bad = 1; exit }
            printf "%s %d\n", errors, days * 86400 + t[1] * 3600 + t[2] * 60 + t[3]
            found = 1
        }
        END { exit (bad || !found) }') || return 1
    valid_nonnegative_integer "${_sr_result% *}" || return 1
    valid_nonnegative_integer "${_sr_result#* }" || return 1
    printf '%s\n' "$_sr_result"
)

# Build tags from ZFS event environment variables
build_tags() (
    _bt_base_tags="$DD_TAGS"
    _bt_pool="${ZEVENT_POOL:-unknown}"
    _bt_vdev="${ZEVENT_VDEV_PATH:-}"
    _bt_vdev_state=$(zevent_vdev_state)

    valid_agent_tags "$_bt_base_tags" || return 1
    valid_zfs_tag_value "$_bt_pool" || return 1
    if [ -n "$_bt_base_tags" ]; then
        _bt_tags="$_bt_base_tags,pool:${_bt_pool}"
    else
        _bt_tags="pool:${_bt_pool}"
    fi

    if [ -n "$_bt_vdev" ]; then
        # Extract device name from path
        _bt_vdev_name=$(basename "$_bt_vdev")
        valid_zfs_tag_value "$_bt_vdev_name" || return 1
        _bt_tags="${_bt_tags},vdev:${_bt_vdev_name}"
    fi

    if [ -n "$_bt_vdev_state" ]; then
        valid_zfs_tag_value "$_bt_vdev_state" || return 1
        _bt_tags="${_bt_tags},vdev_state:${_bt_vdev_state}"
    fi

    valid_agent_tags "$_bt_tags" || return 1
    echo "$_bt_tags"
)

# Functions are sourced, no need to export in POSIX sh
