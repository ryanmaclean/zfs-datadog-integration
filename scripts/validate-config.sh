#!/bin/sh
# Validate the Linux ZED to local Datadog Agent route without sending data.
set -eu

errors=0
warns=0
zed_dir=${ZED_DIR:-/etc/zfs/zed.d}

printf 'ZFS Datadog local Agent configuration\n'
printf '=====================================\n'

if [ "$(uname -s)" != Linux ]; then
    printf 'ERROR: this ZED route is supported only on Linux\n' >&2
    errors=$((errors + 1))
fi

if [ -f "$zed_dir/config.sh" ] && [ ! -L "$zed_dir/config.sh" ]; then
    config=$zed_dir/config.sh
else
    printf 'ERROR: installed config.sh was not found at %s/config.sh\n' "$zed_dir" >&2
    errors=$((errors + 1))
    config=
fi

if [ -n "$config" ]; then
    # The configuration is a root-owned POSIX shell source when installed.
    . "$config"
    if [ "${DOGSTATSD_HOST:-127.0.0.1}" != 127.0.0.1 ]; then
        printf 'ERROR: DogStatsD host must be 127.0.0.1\n' >&2
        errors=$((errors + 1))
    fi
    port=${DOGSTATSD_PORT:-8125}
    case "$port" in ''|*[!0-9]*|0?*) port=invalid ;; esac
    if [ "${#port}" -gt 5 ] || [ "$port" = invalid ] ||
       [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        printf 'ERROR: DogStatsD port must be 1 through 65535\n' >&2
        errors=$((errors + 1))
    fi
    tags=${DD_TAGS:-service:zfs}
    case "$tags" in
        ''|,*|*,|*,,*|*[!A-Za-z0-9_.,:/-]*)
            printf 'ERROR: DD_TAGS contains an invalid or empty tag\n' >&2
            errors=$((errors + 1)) ;;
    esac
    case ",$tags," in *,host:*)
        printf 'ERROR: DD_TAGS must not override Agent host identity\n' >&2
        errors=$((errors + 1)) ;;
    esac
    [ "${#tags}" -le 512 ] || {
        printf 'ERROR: DD_TAGS exceeds 512 bytes\n' >&2
        errors=$((errors + 1))
    }
    printf 'Config: %s\n' "$config"
fi

if ! command -v nc >/dev/null 2>&1; then
    printf 'ERROR: nc is required for local DogStatsD handoff\n' >&2
    errors=$((errors + 1))
fi
if ! command -v systemctl >/dev/null 2>&1 ||
   ! systemctl is-active --quiet datadog-agent; then
    printf 'ERROR: local datadog-agent service is not active\n' >&2
    errors=$((errors + 1))
fi
if ! command -v systemctl >/dev/null 2>&1 ||
   ! systemctl is-active --quiet zfs-zed; then
    printf 'ERROR: zfs-zed service is not active\n' >&2
    errors=$((errors + 1))
fi
for route in zfs-datadog-lib.sh statechange-datadog.sh \
             scrub_start-datadog.sh scrub_finish-datadog.sh \
             resilver_start-datadog.sh resilver_finish-datadog.sh \
             config_sync-datadog.sh pool_import-datadog.sh \
             pool_destroy-datadog.sh vdev_attach-datadog.sh \
             vdev_remove-datadog.sh ereport.fs.zfs.checksum-datadog.sh \
             ereport.fs.zfs.io-datadog.sh .checksum-error.sh .io-error.sh; do
    if [ ! -f "$zed_dir/$route" ] || [ -L "$zed_dir/$route" ]; then
        printf 'ERROR: missing installed route %s\n' "$route" >&2
        errors=$((errors + 1))
    fi
done

printf 'Errors: %s; warnings: %s\n' "$errors" "$warns"
printf 'Local service checks do not prove DogStatsD parsing or Datadog intake.\n'
[ "$errors" -eq 0 ]
