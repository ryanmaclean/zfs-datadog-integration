#!/bin/sh
#
# ZFS Data Error Zedlet
# Reports data ereports to Datadog
#
# Triggered by: ereport.fs.zfs.data events. FreeBSD emits one of these for
# every block that could not be read back correctly (it appeared 206 times
# next to 20 checksum ereports on one real pool), so a pool with damaged data
# is visible even when no vdev checksum counter is incremented.
# Place in: /etc/zfs/zed.d/
#
# The event is about a block, not a vdev: ZED exports no vdev_path or
# vdev_state for it, only the pool and the zio_* fields of the failed I/O.
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/zfs-datadog-lib.sh"

# Enabled unless config.sh turns it off, so an older config.sh without this
# switch keeps working.
if [ "${MONITOR_DATA_ERRORS:-true}" != "true" ]; then
    exit 0
fi

# A zevent field as a number, or "unknown" when absent or not a plain integer.
zevent_uint() {
    if valid_nonnegative_integer "$1"; then
        printf '%s\n' "$1"
    else
        echo unknown
    fi
}

# ZEVENT_ZIO_TYPE looks like "0x1 [READ]". Print the bracketed name, or the
# whole value when it has no brackets, or "unknown" unless it is a plain word.
zevent_zio_type() {
    _zt_type=${1:-}
    case "$_zt_type" in
        *'['*']'*) _zt_type=${_zt_type#*[}; _zt_type=${_zt_type%%]*} ;;
    esac
    if valid_zfs_tag_value "$_zt_type"; then
        printf '%s\n' "$_zt_type"
    else
        echo unknown
    fi
}

# Extract event information
POOL="${ZEVENT_POOL:-unknown}"
ZIO_ERR=$(zevent_uint "${ZEVENT_ZIO_ERR:-}")
ZIO_TYPE=$(zevent_zio_type "${ZEVENT_ZIO_TYPE:-}")
OBJSET=$(zevent_uint "${ZEVENT_ZIO_OBJSET:-}")
OBJECT=$(zevent_uint "${ZEVENT_ZIO_OBJECT:-}")
LEVEL=$(zevent_uint "${ZEVENT_ZIO_LEVEL:-}")
BLKID=$(zevent_uint "${ZEVENT_ZIO_BLKID:-}")

# Build tags. Object and block ids are event text, never tags: they are
# unbounded and would create one metric context per damaged block.
TAGS=$(build_tags) || exit 1
if [ "$ZIO_TYPE" != unknown ]; then
    ZIO_TYPE_TAG=$(printf '%s' "$ZIO_TYPE" | tr '[:upper:]' '[:lower:]')
    TAGS="${TAGS},zio_type:${ZIO_TYPE_TAG}"
fi
SEND_STATUS=0

# Prepare event details
TITLE="ZFS Data Error: $POOL"
TEXT="Pool: $POOL\nZIO Error: $ZIO_ERR\nZIO Type: $ZIO_TYPE\nObjset: $OBJSET\nObject: $OBJECT\nLevel: $LEVEL\nBlock ID: $BLKID"

# Send event to Datadog
send_datadog_event "$TITLE" "$TEXT" "error" "$TAGS" || SEND_STATUS=1

# Send metric (1 per ereport event)
send_metric "zfs.data.error" "1" "counter" "$TAGS" || SEND_STATUS=1

log_message "ERROR" "Data error detected: $POOL - objset $OBJSET object $OBJECT level $LEVEL blkid $BLKID"

exit "$SEND_STATUS"
