#!/bin/sh
#
# ZFS Datadog Integration Installation Script
# Installs zedlets and configures the ZFS Event Daemon (ZED)
#
# POSIX sh — runs on Linux, FreeBSD, NetBSD, TrueNAS CORE/SCALE, illumos.
#
# Override autodetection with environment variables:
#   ZED_DIR=/path/to/zed.d   ./install.sh
#   SKIP_RESTART=1           ./install.sh
#

set -e

# Prevent Next.js from sending telemetry if invoked during install.
NEXT_TELEMETRY_DISABLED=1
export NEXT_TELEMETRY_DISABLED

# ---------------------------------------------------------------- output ----
# printf, not "echo -e": echo's escape handling is not portable.
if [ -t 1 ] && [ -z "${NO_COLOR}" ]; then
    RED=$(printf '\033[0;31m'); GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[1;33m'); NC=$(printf '\033[0m')
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

err()  { printf '%sError: %s%s\n' "$RED" "$1" "$NC" >&2; }
warn() { printf '%s! %s%s\n' "$YELLOW" "$1" "$NC"; }
ok()   { printf '%s* %s%s\n' "$GREEN" "$1" "$NC"; }

# ------------------------------------------------------------------ root ----
# "id -u" is POSIX; $EUID is a bashism.
if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root"
    exit 1
fi

OS=$(uname -s)

# --------------------------------------------------------------- ZED dir ----
# Linux and FreeBSD base OpenZFS use /etc/zfs/zed.d.
# FreeBSD's sysutils/openzfs port installs under /usr/local.
if [ -n "${ZED_DIR}" ]; then
    if [ ! -d "$ZED_DIR" ]; then
        err "ZED_DIR was set to '$ZED_DIR' but that directory does not exist"
        exit 1
    fi
else
    for candidate in /etc/zfs/zed.d /usr/local/etc/zfs/zed.d; do
        if [ -d "$candidate" ]; then
            ZED_DIR="$candidate"
            break
        fi
    done
fi

if [ -z "${ZED_DIR}" ]; then
    err "Could not find a zed.d directory"
    printf 'Looked in: /etc/zfs/zed.d, /usr/local/etc/zfs/zed.d\n'
    case "$OS" in
        FreeBSD) printf 'On FreeBSD, OpenZFS is in base on 13+; from ports install sysutils/openzfs.\n' ;;
        *)       printf 'Please ensure OpenZFS (and ZED) is installed.\n' ;;
    esac
    printf 'If your zed.d lives elsewhere: ZED_DIR=/path/to/zed.d %s\n' "$0"
    exit 1
fi

# "cd; pwd" instead of ${BASH_SOURCE[0]} — works under any POSIX sh.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

printf '%sZFS Datadog Integration Installer%s\n' "$GREEN" "$NC"
printf '==================================\n'
printf 'OS:      %s\n' "$OS"
printf 'ZED dir: %s\n\n' "$ZED_DIR"

# -------------------------------------------------------- dependencies ----
printf 'Checking dependencies...\n'
MISSING=''
command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
command -v nc   >/dev/null 2>&1 || MISSING="$MISSING nc"

if [ -n "$MISSING" ]; then
    err "Missing dependencies:$MISSING"
    case "$OS" in
        FreeBSD)
            # nc(1) is in FreeBSD base; curl is not.
            printf 'Install with: pkg install%s\n' "$MISSING"
            ;;
        Linux)
            printf 'Install curl and a netcat (netcat-openbsd or nmap-ncat) via your package manager.\n'
            ;;
        *)
            printf 'Install the missing tools with your package manager.\n'
            ;;
    esac
    exit 1
fi
ok "All dependencies found"
printf '\n'

# --------------------------------------------------------------- payload ----
# The library plus every zedlet in the repo.
#
# NOTE: the ereport.fs.zfs.* files are the ZED dispatch entry points. ZED
# matches a zedlet to an event by filename prefix, so checksum-error.sh and
# io-error.sh are never invoked on their own — the wrappers exec them. Omitting
# the wrappers silently disables checksum and I/O error reporting, which is
# what the previous version of this script did.
LIB='zfs-datadog-lib.sh'

ZEDLETS='all-datadog.sh
statechange-datadog.sh
scrub_start-datadog.sh
scrub_finish-datadog.sh
resilver_start-datadog.sh
resilver_finish-datadog.sh
config_sync-datadog.sh
pool_import-datadog.sh
pool_destroy-datadog.sh
vdev_attach-datadog.sh
vdev_remove-datadog.sh
ereport.fs.zfs.checksum-datadog.sh
ereport.fs.zfs.io-datadog.sh
checksum-error.sh
io-error.sh'

printf 'Checking source files...\n'
MISSING_SRC=''
for f in $LIB $ZEDLETS; do
    [ -f "$SCRIPT_DIR/$f" ] || MISSING_SRC="$MISSING_SRC $f"
done
if [ -n "$MISSING_SRC" ]; then
    err "Missing source files:$MISSING_SRC"
    exit 1
fi
ok "All source files found"
printf '\n'

# ---------------------------------------------------------------- config ----
# config.sh holds the API key. Never clobber an existing one.
printf 'Handling configuration...\n'
if [ -f "$ZED_DIR/config.sh" ]; then
    ok "Existing $ZED_DIR/config.sh left untouched"
    CONFIG_IS_NEW=0
elif [ -f "$SCRIPT_DIR/config.sh" ]; then
    cp "$SCRIPT_DIR/config.sh" "$ZED_DIR/config.sh"
    ok "Installed config.sh"
    CONFIG_IS_NEW=1
elif [ -f "$SCRIPT_DIR/config.sh.example" ]; then
    cp "$SCRIPT_DIR/config.sh.example" "$ZED_DIR/config.sh"
    ok "Created config.sh from config.sh.example"
    CONFIG_IS_NEW=1
else
    err "No config.sh or config.sh.example found in $SCRIPT_DIR"
    exit 1
fi
chmod 600 "$ZED_DIR/config.sh"
printf '\n'

# --------------------------------------------------------------- install ----
printf 'Installing to %s...\n' "$ZED_DIR"
cp "$SCRIPT_DIR/$LIB" "$ZED_DIR/$LIB"
chmod 644 "$ZED_DIR/$LIB"          # sourced, not executed
printf '  %s\n' "$LIB"

for f in $ZEDLETS; do
    cp "$SCRIPT_DIR/$f" "$ZED_DIR/$f"
    chmod 755 "$ZED_DIR/$f"
    printf '  %s\n' "$f"
done
ok "Files installed"
printf '\n'

# Warn if the API key still looks unset. Uses POSIX grep -E, not GNU grep -q ".\+".
if ! grep -E '^[[:space:]]*(export[[:space:]]+)?DD_API_KEY=["'"'"']?[A-Za-z0-9]' \
        "$ZED_DIR/config.sh" >/dev/null 2>&1; then
    warn "DD_API_KEY does not appear to be set in $ZED_DIR/config.sh"
fi

# ----------------------------------------------------- FreeBSD: zfsd/zed ----
# FreeBSD's traditional fault-management daemon is zfsd(8), not ZED. ZED ships
# with OpenZFS but is not enabled by default, so zedlets will never fire unless
# it is turned on. This is a deployment decision, not something to auto-change.
if [ "$OS" = "FreeBSD" ]; then
    if command -v sysrc >/dev/null 2>&1; then
        ZED_ENABLED=$(sysrc -n zed_enable 2>/dev/null || echo NO)
        ZFSD_ENABLED=$(sysrc -n zfsd_enable 2>/dev/null || echo NO)
        case "$ZED_ENABLED" in
            [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1) : ;;
            *)
                warn "zed is not enabled in rc.conf — zedlets will not fire"
                printf '    Enable it with:  sysrc zed_enable=YES && service zed start\n'
                ;;
        esac
        case "$ZFSD_ENABLED" in
            [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
                warn "zfsd is also enabled. zfsd and zed both consume ZFS events."
                printf '    That is supported, but decide deliberately which one owns\n'
                printf '    fault handling on this host before relying on either.\n'
                ;;
        esac
    fi
    printf '\n'
fi

# --------------------------------------------------------------- restart ----
if [ -n "${SKIP_RESTART}" ]; then
    warn "SKIP_RESTART set — not restarting ZED"
else
    printf 'Restarting ZFS Event Daemon...\n'
    if [ "$OS" = "FreeBSD" ] && command -v service >/dev/null 2>&1; then
        if service zed restart >/dev/null 2>&1; then
            ok "ZED restarted via service(8)"
        else
            warn "Could not restart zed via service(8) — start it manually"
        fi
    elif command -v systemctl >/dev/null 2>&1; then
        if systemctl restart zfs-zed >/dev/null 2>&1; then
            ok "ZED restarted via systemctl"
        else
            warn "systemctl could not restart zfs-zed — restart it manually"
        fi
    elif [ -x /etc/init.d/zfs-zed ]; then
        if /etc/init.d/zfs-zed restart; then
            ok "ZED restarted via init.d"
        else
            warn "init.d could not restart zfs-zed — restart it manually"
        fi
    elif command -v svcadm >/dev/null 2>&1; then
        if svcadm restart system/fm/zfs-events 2>/dev/null; then
            ok "ZED restarted via svcadm"
        else
            warn "Could not restart ZED via svcadm — restart it manually"
        fi
    else
        warn "Could not determine how to restart ZED — please restart it manually"
    fi
fi
printf '\n'

# ------------------------------------------------------------------ done ----
ok "Installation complete"
printf '\nNext steps:\n'
if [ "$CONFIG_IS_NEW" -eq 1 ]; then
    printf '1. Edit %s/config.sh and set DD_API_KEY\n' "$ZED_DIR"
else
    printf '1. Confirm DD_API_KEY is still correct in %s/config.sh\n' "$ZED_DIR"
fi
printf '2. Ensure the Datadog Agent is running (DogStatsD on %s)\n' "${DOGSTATSD_PORT:-8125}"
case "$OS" in
    FreeBSD)
        printf '3. Watch ZED output:   tail -f /var/log/messages | grep zed\n'
        ;;
    *)
        if [ -f /var/log/zfs/zed.log ]; then
            printf '3. Watch ZED output:   tail -f /var/log/zfs/zed.log\n'
        else
            printf '3. Watch ZED output:   journalctl -fu zfs-zed   (or your syslog)\n'
        fi
        ;;
esac
printf '4. Test with:           zpool scrub <poolname>\n'
printf '\nSee README.md for more.\n'
