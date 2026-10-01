#!/bin/bash
#
# ZFS Datadog Integration Configuration
# 
#

# Source .env.local if it exists (for local development/testing)
if [ -f "$(dirname "$0")/.env.local" ]; then
    . "$(dirname "$0")/.env.local"
elif [ -f "/etc/zfs/zed.d/.env.local" ]; then
    . "/etc/zfs/zed.d/.env.local"
fi

# Datadog API Configuration
DD_API_KEY="${DD_API_KEY:-}"
DD_SITE="${DD_SITE:-datadoghq.com}"
DD_API_URL="${DD_API_URL:-https://api.${DD_SITE}}"

# DogStatsD Configuration
# Default: localhost:8125 (Datadog Agent must be running)
DOGSTATSD_HOST="${DOGSTATSD_HOST:-localhost}"
DOGSTATSD_PORT="${DOGSTATSD_PORT:-8125}"

# Default tags for all events and metrics
# Format: comma-separated key:value pairs
DD_TAGS="${DD_TAGS:-env:production,service:zfs}"

# Hostname override (optional)
# If not set, will use system hostname
# HOSTNAME="${HOSTNAME:-}"

# Enable/disable specific monitoring
MONITOR_POOL_HEALTH="${MONITOR_POOL_HEALTH:-true}"
MONITOR_SCRUB="${MONITOR_SCRUB:-true}"
MONITOR_RESILVER="${MONITOR_RESILVER:-true}"
MONITOR_CHECKSUM_ERRORS="${MONITOR_CHECKSUM_ERRORS:-true}"
MONITOR_IO_ERRORS="${MONITOR_IO_ERRORS:-true}"
