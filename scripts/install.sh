#!/bin/sh
#
# ZFS Datadog Integration Installation Script
# Installs zedlets and configures the ZFS Event Daemon (ZED)
#
# POSIX sh — ZED hosts only; FreeBSD base is intentionally fail-closed.
#
# Override autodetection with environment variables:
#   ZED_DIR=/path/to/zed.d   ./install.sh
# This installer deliberately rejects existing integration files. Upgrades
# require a separately verified migration; never activate beside old routes.
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

OS=$(uname -s) || { err "Cannot determine host OS"; exit 1; }
[ -n "$OS" ] || { err "Host OS was empty"; exit 1; }

# Base FreeBSD uses zfsd/devd; copying ZED zedlets cannot enable delivery.
# Refuse before destination discovery, directory/config writes or restart.
if [ "$OS" = "FreeBSD" ]; then
    err "FreeBSD native ZFS event delivery is not installed by this ZED installer"
    printf 'No ZED files or ZFS services were changed.\n' >&2
    exit 1
fi
if [ "$OS" != "Linux" ]; then
    err "This installer has no verified ZED activation contract for $OS"
    exit 1
fi
if [ -n "${SKIP_RESTART:-}" ]; then
    err "SKIP_RESTART cannot establish an active single-route installation"
    exit 1
fi

# --------------------------------------------------------------- ZED dir ----
# Linux distributions create /etc/zfs/zed.d as part of packaging ZED, so on
# Linux an absent directory genuinely means ZED is not installed.
#
# A ZED destination must be configured for the target platform.
if [ -n "${ZED_DIR:-}" ]; then
    [ -d "$ZED_DIR" ] || { err "Configured ZED directory does not exist"; exit 1; }
else
    for candidate in /etc/zfs/zed.d /usr/local/etc/zfs/zed.d; do
        if [ -d "$candidate" ]; then
            ZED_DIR="$candidate"
            break
        fi
    done
fi

# A root-run copy is safe only below root-owned, non-writable ancestry. On
# other platforms stat differs, so the OS gate above refuses instead of
# guessing. The directory must already exist; installer never creates it.
case "$ZED_DIR" in /*) ;; *) err "ZED_DIR must be absolute"; exit 1 ;; esac
case "$ZED_DIR" in
    /|*/|*//*|*/./*|*/../*|*/.|*/..|*[!A-Za-z0-9_./-]*)
        err "ZED_DIR must be a simple absolute directory path"
        exit 1
        ;;
esac
trust_path=$ZED_DIR
while :; do
    [ ! -L "$trust_path" ] || { err "Symlink in ZED path: $trust_path"; exit 1; }
    [ -d "$trust_path" ] || { err "Missing ZED path component: $trust_path"; exit 1; }
    trust_meta=$(stat -c '%u:%a' "$trust_path") || exit 1
    trust_uid=${trust_meta%%:*}
    trust_mode=${trust_meta#*:}
    [ "$trust_uid" = 0 ] || { err "Non-root ZED path component: $trust_path"; exit 1; }
    case "$trust_mode" in *[!0-7]*|'') err "Invalid ZED path mode"; exit 1 ;; esac
    trust_bits=$((0$trust_mode))
    [ "$((trust_bits & 0022))" -eq 0 ] || {
        err "Writable ZED path component: $trust_path"
        exit 1
    }
    [ "$trust_path" = / ] && break
    trust_path=$(dirname "$trust_path")
done

if [ -z "${ZED_DIR}" ]; then
    err "Could not find a zed.d directory"
    printf 'Looked in: /etc/zfs/zed.d, /usr/local/etc/zfs/zed.d\n'
    printf 'Please ensure OpenZFS and ZED are installed.\n'
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
# Only the two ereport wrappers are enabled for checksum and I/O. The
# executable handlers are dotfiles, which ZED ignores by definition. The
# former all-datadog router and public helper names are upgrade conflicts.
LIB='zfs-datadog-lib.sh'

ZEDLETS='statechange-datadog.sh
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
ereport.fs.zfs.io-datadog.sh'
HANDLERS='checksum-error.sh io-error.sh'
OLD_ROUTES='all-datadog.sh checksum-error.sh io-error.sh'

printf 'Checking source files...\n'
MISSING_SRC=''
for f in $LIB $ZEDLETS $HANDLERS; do
    [ -f "$SCRIPT_DIR/$f" ] || MISSING_SRC="$MISSING_SRC $f"
done
if [ -n "$MISSING_SRC" ]; then
    err "Missing source files:$MISSING_SRC"
    exit 1
fi
ok "All source files found"
printf '\n'

# Refuse old and partial installations before touching a configuration or
# ZED. An unknown or modified old route cannot be retired by filename alone.
for f in $LIB $ZEDLETS $OLD_ROUTES .checksum-error.sh .io-error.sh config.sh .env.local; do
    if [ -e "$ZED_DIR/$f" ] || [ -L "$ZED_DIR/$f" ]; then
        err "Existing integration path requires reviewed migration: $ZED_DIR/$f"
        exit 1
    fi
done
if ! command -v systemctl >/dev/null 2>&1 ||
   ! systemctl is-active --quiet zfs-zed; then
    err "A running systemd zfs-zed service is required for safe activation"
    exit 1
fi

# Stage in the root-only enabled directory under a name ZED will not scan.
# No integration paths existed at preflight, so rollback can remove only the
# files this invocation introduced. A stopped ZED cannot consume mixed files.
umask 077
stage="$ZED_DIR/.zfs-datadog-stage.$$"
stage_owned=0
installed=''
zed_stopped=0
committed=0
cleanup() {
    result=$1
    trap - EXIT
    set +e
    if [ "$committed" -eq 0 ]; then
        if [ "$zed_stopped" -eq 1 ]; then
            systemctl stop zfs-zed >/dev/null 2>&1 ||
                err "Rollback could not stop zfs-zed; service state is unknown"
        fi
        for path in $installed; do rm -f "$path"; done
        if [ "$zed_stopped" -eq 1 ]; then
            if ! systemctl start zfs-zed >/dev/null 2>&1; then
                err "Rollback could not restart zfs-zed; inspect service state"
            fi
        fi
    fi
    if [ "$stage_owned" -eq 1 ]; then rm -rf "$stage"; fi
    exit "$result"
}
trap 'cleanup $?' EXIT
trap 'exit 1' HUP INT TERM
mkdir -m 700 "$stage"
stage_owned=1
for f in $LIB $ZEDLETS $HANDLERS; do
    cp "$SCRIPT_DIR/$f" "$stage/$f"
    cmp -s "$SCRIPT_DIR/$f" "$stage/$f" || { err "Stage verification failed: $f"; exit 1; }
done
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    cp "$SCRIPT_DIR/config.sh" "$stage/config.sh"
elif [ -f "$SCRIPT_DIR/config.sh.example" ]; then
    cp "$SCRIPT_DIR/config.sh.example" "$stage/config.sh"
else
    err "No configuration source"
    exit 1
fi
chmod 644 "$stage/$LIB"
chmod 600 "$stage/config.sh"
for f in $ZEDLETS $HANDLERS; do chmod 755 "$stage/$f"; done

systemctl stop zfs-zed || { err "Cannot quiesce zfs-zed"; exit 1; }
zed_stopped=1
if systemctl is-active --quiet zfs-zed; then
    err "zfs-zed is still active after stop"
    exit 1
fi
for f in $LIB config.sh; do
    installed="$installed $ZED_DIR/$f"
    mv "$stage/$f" "$ZED_DIR/$f"
done
for f in $HANDLERS; do
    installed="$installed $ZED_DIR/.$f"
    mv "$stage/$f" "$ZED_DIR/.$f"
done
for f in $ZEDLETS; do
    installed="$installed $ZED_DIR/$f"
    mv "$stage/$f" "$ZED_DIR/$f"
done
systemctl start zfs-zed || { err "Cannot start zfs-zed after activation"; exit 1; }
systemctl is-active --quiet zfs-zed || { err "zfs-zed did not become active"; exit 1; }
committed=1
ok "Single-route files activated; zfs-zed is active"
printf '\n'

# ------------------------------------------------------------------ done ----
ok "File activation complete; Datadog intake is not yet verified"
printf '\nNext steps:\n'
printf '1. Edit %s/config.sh and set DD_API_KEY\n' "$ZED_DIR"
printf '2. Ensure the Datadog Agent is running (DogStatsD on %s)\n' "${DOGSTATSD_PORT:-8125}"
if [ -f /var/log/zfs/zed.log ]; then
    printf '3. Watch ZED output:   tail -f /var/log/zfs/zed.log\n'
else
    printf '3. Watch ZED output:   journalctl -fu zfs-zed   (or your syslog)\n'
fi
printf '4. Test with:           zpool scrub <poolname>\n'
printf '\nSee README.md for more.\n'
