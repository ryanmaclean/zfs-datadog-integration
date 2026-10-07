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

# Root execution from a user-writable checkout (especially /tmp) would let a
# different user swap a handler between preflight and staging. Require a
# sealed root-owned source tree; image builders may copy their payload into
# /root first, then invoke this script there.
source_path=$SCRIPT_DIR
while :; do
    [ ! -L "$source_path" ] && [ -d "$source_path" ] || {
        err "Unsafe source path: $source_path"; exit 1;
    }
    source_meta=$(stat -c '%u:%a' "$source_path") || exit 1
    [ "${source_meta%%:*}" = 0 ] || { err "Non-root source path: $source_path"; exit 1; }
    source_mode=${source_meta#*:}
    source_bits=$((0$source_mode))
    [ "$((source_bits & 0022))" -eq 0 ] || {
        err "Writable source path: $source_path"; exit 1;
    }
    [ "$source_path" = / ] && break
    source_path=$(dirname "$source_path")
done

# A failed or interrupted run leaves the lock for manual inspection. Never
# steal it: a concurrent installer could otherwise replace another run's files.
umask 077
lock="$ZED_DIR/.zfs-datadog-install.lock"
if ! mkdir -m 700 "$lock" 2>/dev/null; then
    err "Installation lock exists: $lock"
    exit 1
fi
lock_owned=1
release_lock() {
    if [ "$lock_owned" -eq 1 ]; then
        rmdir "$lock" || err "Could not release installation lock: $lock"
        lock_owned=0
    fi
}
trap 'release_lock' EXIT
trap 'exit 1' HUP INT TERM

printf '%sZFS Datadog Integration Installer%s\n' "$GREEN" "$NC"
printf '==================================\n'
printf 'OS:      %s\n' "$OS"
printf 'ZED dir: %s\n\n' "$ZED_DIR"

# -------------------------------------------------------- dependencies ----
printf 'Checking dependencies...\n'
MISSING=''
command -v curl >/dev/null 2>&1 || MISSING="$MISSING curl"
command -v nc   >/dev/null 2>&1 || MISSING="$MISSING nc"
command -v openssl >/dev/null 2>&1 || MISSING="$MISSING openssl"

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
    [ -f "$SCRIPT_DIR/$f" ] && [ ! -L "$SCRIPT_DIR/$f" ] || MISSING_SRC="$MISSING_SRC $f"
done
if [ -n "$MISSING_SRC" ]; then
    err "Missing source files:$MISSING_SRC"
    exit 1
fi
ok "All source files found"
printf '\n'
for f in install.sh payload.sha256 $LIB $ZEDLETS $HANDLERS config.sh config.sh.example; do
    [ -f "$SCRIPT_DIR/$f" ] || continue
    [ ! -L "$SCRIPT_DIR/$f" ] || { err "Symlinked source file: $f"; exit 1; }
    src_meta=$(stat -c '%u:%a' "$SCRIPT_DIR/$f") || exit 1
    [ "${src_meta%%:*}" = 0 ] || { err "Non-root source file: $f"; exit 1; }
    src_mode=${src_meta#*:}
    src_bits=$((0$src_mode))
    [ "$((src_bits & 0022))" -eq 0 ] || { err "Writable source file: $f"; exit 1; }
done

# Callers must pin the reviewed manifest digest outside this uploaded script.
# The caller verifies install.sh itself before root execution. Once running,
# this check binds every payload byte to that reviewed manifest before service
# or destination changes.
case "${ZFS_DD_EXPECTED_MANIFEST_SHA:-}" in
    ????????????????????????????????????????????????????????????????) ;;
    *) err "Expected payload manifest SHA-256 is required"; exit 1 ;;
esac
case "$ZFS_DD_EXPECTED_MANIFEST_SHA" in
    *[!0-9a-f]*) err "Invalid payload manifest SHA-256"; exit 1 ;;
esac
manifest="$SCRIPT_DIR/payload.sha256"
command -v openssl >/dev/null 2>&1 || { err "openssl is required"; exit 1; }
manifest_digest=$(openssl dgst -sha256 "$manifest") || exit 1
[ "${manifest_digest##*= }" = "$ZFS_DD_EXPECTED_MANIFEST_SHA" ] || {
    err "Payload manifest differs from reviewed digest"; exit 1;
}
payload_count=0
payload_seen=' '
while read -r expected name extra; do
    [ -z "${extra:-}" ] || { err "Malformed payload manifest"; exit 1; }
    case "$expected" in
        ????????????????????????????????????????????????????????????????) ;;
        *) err "Malformed payload hash"; exit 1 ;;
    esac
    case "$expected" in *[!0-9a-f]*) err "Malformed payload hash"; exit 1 ;; esac
    case "$name" in
        install.sh|config.sh|zfs-datadog-lib.sh|checksum-error.sh|io-error.sh|\
        statechange-datadog.sh|scrub_start-datadog.sh|scrub_finish-datadog.sh|\
        resilver_start-datadog.sh|resilver_finish-datadog.sh|\
        config_sync-datadog.sh|pool_import-datadog.sh|pool_destroy-datadog.sh|\
        vdev_attach-datadog.sh|vdev_remove-datadog.sh|\
        ereport.fs.zfs.checksum-datadog.sh|ereport.fs.zfs.io-datadog.sh) ;;
        *) err "Unknown payload name: $name"; exit 1 ;;
    esac
    case "$payload_seen" in *" $name "*) err "Duplicate payload name: $name"; exit 1 ;; esac
    payload_seen="$payload_seen$name "
    file_digest=$(openssl dgst -sha256 "$SCRIPT_DIR/$name") || exit 1
    [ "${file_digest##*= }" = "$expected" ] || {
        err "Payload differs from reviewed manifest: $name"; exit 1;
    }
    payload_count=$((payload_count + 1))
done < "$manifest"
[ "$payload_count" -eq 17 ] || { err "Incomplete payload manifest"; exit 1; }

# Refuse old and partial installations before touching a configuration or
# ZED. An unknown or modified old route cannot be retired by filename alone.
for f in $LIB $ZEDLETS $OLD_ROUTES .checksum-error.sh .io-error.sh config.sh .env.local .zfs-datadog.manifest; do
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
        rollback_quiesced=0
        if [ "$zed_stopped" -eq 1 ]; then
            if ! systemctl stop zfs-zed >/dev/null 2>&1 ||
               systemctl is-active --quiet zfs-zed; then
                err "Rollback could not quiesce zfs-zed; installed paths preserved for recovery"
                installed=''
            else
                rollback_quiesced=1
            fi
        fi
        for path in $installed; do rm -f "$path"; done
        if [ "$rollback_quiesced" -eq 1 ]; then
            if ! systemctl start zfs-zed >/dev/null 2>&1; then
                err "Rollback could not restart zfs-zed; inspect service state"
            fi
        fi
    fi
    if [ "$stage_owned" -eq 1 ]; then rm -rf "$stage"; fi
    release_lock
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

# Manifest is the uninstall authority. It binds exact owned postimages to
# explicit basenames; no wildcard removal or filename-only ownership claim.
: > "$stage/.zfs-datadog.manifest"
for f in $LIB config.sh; do
    digest=$(openssl dgst -sha256 "$stage/$f") || exit 1
    printf '%s %s\n' "${digest##*= }" "$f" >> "$stage/.zfs-datadog.manifest"
done
for f in $HANDLERS; do
    digest=$(openssl dgst -sha256 "$stage/$f") || exit 1
    printf '%s .%s\n' "${digest##*= }" "$f" >> "$stage/.zfs-datadog.manifest"
done
for f in $ZEDLETS; do
    digest=$(openssl dgst -sha256 "$stage/$f") || exit 1
    printf '%s %s\n' "${digest##*= }" "$f" >> "$stage/.zfs-datadog.manifest"
done
chmod 600 "$stage/.zfs-datadog.manifest"

systemctl stop zfs-zed || { err "Cannot quiesce zfs-zed"; exit 1; }
zed_stopped=1
if systemctl is-active --quiet zfs-zed; then
    err "zfs-zed is still active after stop"
    exit 1
fi
for f in $LIB config.sh; do
    ln "$stage/$f" "$ZED_DIR/$f" || { err "Activation collision: $f"; exit 1; }
    installed="$installed $ZED_DIR/$f"
done
for f in $HANDLERS; do
    ln "$stage/$f" "$ZED_DIR/.$f" || { err "Activation collision: .$f"; exit 1; }
    installed="$installed $ZED_DIR/.$f"
done
for f in $ZEDLETS; do
    ln "$stage/$f" "$ZED_DIR/$f" || { err "Activation collision: $f"; exit 1; }
    installed="$installed $ZED_DIR/$f"
done
ln "$stage/.zfs-datadog.manifest" "$ZED_DIR/.zfs-datadog.manifest" || {
    err "Manifest activation collision"
    exit 1
}
installed="$installed $ZED_DIR/.zfs-datadog.manifest"
systemctl start zfs-zed || { err "Cannot start zfs-zed after activation"; exit 1; }
systemctl is-active --quiet zfs-zed || { err "zfs-zed did not become active"; exit 1; }
committed=1
rm -rf "$stage"
stage_owned=0
release_lock
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
