#!/bin/sh
# Remove only the files recorded by the single-route Linux ZED installer.
set -e

dry_run=0
keep_config=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --keep-config) keep_config=1 ;;
        -h|--help) printf 'Usage: %s [--dry-run] [--keep-config]\n' "$0"; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || die 'Only Linux ZED installations are managed here'
[ "$(id -u)" -eq 0 ] || die 'Run as root, including for the locked dry run'
command -v openssl >/dev/null 2>&1 || die 'openssl is required to verify ownership'

if [ -z "${ZED_DIR:-}" ]; then
    for candidate in /etc/zfs/zed.d /usr/local/etc/zfs/zed.d; do
        if [ -d "$candidate" ]; then ZED_DIR=$candidate; break; fi
    done
fi
case "${ZED_DIR:-}" in /*) ;; *) die 'No absolute ZED directory found' ;; esac
case "$ZED_DIR" in
    /|*/|*//*|*/./*|*/../*|*/.|*/..|*[!A-Za-z0-9_./-]*) die 'Unsafe ZED directory path' ;;
esac
trust_path=$ZED_DIR
while :; do
    [ ! -L "$trust_path" ] && [ -d "$trust_path" ] || die "Unsafe ZED path: $trust_path"
    trust_meta=$(stat -c '%u:%a' "$trust_path") || exit 1
    trust_uid=${trust_meta%%:*}
    trust_mode=${trust_meta#*:}
    [ "$trust_uid" = 0 ] || die "Non-root ZED path: $trust_path"
    case "$trust_mode" in *[!0-7]*|'') die 'Invalid ZED path mode' ;; esac
    trust_bits=$((0$trust_mode))
    [ "$((trust_bits & 0022))" -eq 0 ] || die "Writable ZED path: $trust_path"
    [ "$trust_path" = / ] && break
    trust_path=$(dirname "$trust_path")
done

lock="$ZED_DIR/.zfs-datadog-install.lock"
umask 077
mkdir -m 700 "$lock" 2>/dev/null || die "Installation lock exists: $lock"
release_lock() { rmdir "$lock" || printf 'Error: lock remains: %s\n' "$lock" >&2; }
trap 'release_lock' EXIT
trap 'exit 1' HUP INT TERM

manifest="$ZED_DIR/.zfs-datadog.manifest"
[ -f "$manifest" ] && [ ! -L "$manifest" ] || die 'Owned install manifest is absent or unsafe'
[ "$(stat -c %u "$manifest")" = 0 ] || die 'Manifest is not root-owned'
manifest_mode=$(stat -c %a "$manifest") || exit 1
manifest_bits=$((0$manifest_mode))
[ "$((manifest_bits & 0077))" -eq 0 ] || die 'Manifest is not private'

# Parse the complete allowlist before stopping ZED. Any missing, modified,
# duplicated or symlinked target needs reviewed recovery, not blind removal.
count=0
seen=' '
while read -r expected name extra; do
    [ -z "${extra:-}" ] || die 'Malformed manifest line'
    case "$expected" in
        ????????????????????????????????????????????????????????????????) ;;
        *) die 'Malformed SHA-256 in manifest' ;;
    esac
    case "$expected" in *[!0-9a-f]*) die 'Malformed SHA-256 in manifest' ;; esac
    case "$name" in
        zfs-datadog-lib.sh|config.sh|.checksum-error.sh|.io-error.sh|\
        statechange-datadog.sh|scrub_start-datadog.sh|scrub_finish-datadog.sh|\
        resilver_start-datadog.sh|resilver_finish-datadog.sh|\
        config_sync-datadog.sh|pool_import-datadog.sh|pool_destroy-datadog.sh|\
        vdev_attach-datadog.sh|vdev_remove-datadog.sh|\
        ereport.fs.zfs.checksum-datadog.sh|ereport.fs.zfs.io-datadog.sh) ;;
        *) die "Unknown manifest target: $name" ;;
    esac
    case "$seen" in *" $name "*) die "Duplicate manifest target: $name" ;; esac
    seen="$seen$name "
    target="$ZED_DIR/$name"
    [ -f "$target" ] && [ ! -L "$target" ] || die "Missing or unsafe target: $target"
    [ "$(stat -c %u "$target")" = 0 ] || die "Non-root target: $target"
    if [ "$keep_config" -eq 0 ] || [ "$name" != config.sh ]; then
        digest=$(openssl dgst -sha256 "$target") || exit 1
        [ "${digest##*= }" = "$expected" ] || die "Modified target: $target"
    fi
    count=$((count + 1))
done < "$manifest"
[ "$count" -eq 16 ] || die "Incomplete manifest: $count of 16 expected paths"

if [ "$dry_run" -eq 1 ]; then
    printf 'Verified %s owned paths; would stop ZED and remove them%s.\n' \
        "$count" "$(if [ "$keep_config" -eq 1 ]; then printf ' except config.sh'; fi)"
    exit 0
fi

command -v systemctl >/dev/null 2>&1 || die 'systemctl is required'
systemctl is-active --quiet zfs-zed || die 'zfs-zed is not active; inspect before removal'
systemctl stop zfs-zed || die 'Could not stop zfs-zed; no files removed'
if systemctl is-active --quiet zfs-zed; then die 'zfs-zed remains active; no files removed'; fi

while read -r expected name extra; do
    if [ "$name" = config.sh ] && [ "$keep_config" -eq 1 ]; then continue; fi
    rm -f "$ZED_DIR/$name"
done < "$manifest"
rm -f "$manifest"
systemctl start zfs-zed || die 'Files removed, but zfs-zed did not restart'
systemctl is-active --quiet zfs-zed || die 'Files removed, but zfs-zed is not active'
printf 'Removed verified single-route files; zfs-zed is active.\n'
