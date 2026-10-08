#!/bin/sh
#
# ZFS Datadog Integration Configuration
# 
#

# The local Datadog Agent handles intake authentication and host identity.
# No API key or direct HTTP endpoint belongs in a ZED zedlet configuration.
# DogStatsD is deliberately restricted to loopback by zfs-datadog-lib.sh.
DOGSTATSD_HOST="${DOGSTATSD_HOST:-127.0.0.1}"
DOGSTATSD_PORT="${DOGSTATSD_PORT:-8125}"

# Default ZFS service tag for all events and metrics. Configure env and other
# host-wide tags on the local Datadog Agent, which also supplies host identity.
# Format: comma-separated key:value pairs
DD_TAGS="${DD_TAGS:-service:zfs}"

# Enable/disable specific monitoring
MONITOR_POOL_HEALTH="${MONITOR_POOL_HEALTH:-true}"
MONITOR_SCRUB="${MONITOR_SCRUB:-true}"
MONITOR_RESILVER="${MONITOR_RESILVER:-true}"
MONITOR_CHECKSUM_ERRORS="${MONITOR_CHECKSUM_ERRORS:-true}"
MONITOR_IO_ERRORS="${MONITOR_IO_ERRORS:-true}"
