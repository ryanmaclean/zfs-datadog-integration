#!/bin/sh
# Golden-output regression test for everything scripts/install.sh ships.
#
# Every zedlet named in install.sh, plus the shared library, is copied into a
# throwaway ZED directory and run against fixed ZEVENT_* inputs. curl, nc,
# logger, hostname and sleep are replaced by recording stubs, so the exact
# Events API payloads, DogStatsD lines and log lines are captured without any
# network access. The transcript must match .github/tests/zedlet-payloads.golden
# byte for byte. The golden file was generated from the pre-ShellCheck-cleanup
# scripts (master 1b72e2b), so a lint fix that changes what is sent fails here.
#
# Usage: .github/scripts/test-zedlet-payloads.sh [shell ...]
#   Each shell (default: sh, plus dash and bash when installed) runs the full
#   suite; every run must produce the golden transcript.
#   Set ZEDLET_PAYLOADS_WRITE=path to write the transcript there instead of
#   comparing (used once, to create the golden file from the old scripts).
set -eu
cd "$(git rev-parse --show-toplevel)"

golden=.github/tests/zedlet-payloads.golden
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# ---------------------------------------------------------------- shipped set
# Parse LIB and ZEDLETS from install.sh so this test follows the installer.
lib=$(sed -n "s/^LIB='\\(.*\\)'\$/\\1/p" scripts/install.sh)
zedlets=$(sed -n "/^ZEDLETS='/,/'\$/p" scripts/install.sh | tr -d "'" | sed 's/^ZEDLETS=//')
if [ -z "$lib" ] || [ -z "$zedlets" ]; then
    echo "Could not read LIB/ZEDLETS from scripts/install.sh" >&2
    exit 1
fi

# --------------------------------------------------------------------- stubs
mkdir "$work/bin"
cat > "$work/bin/curl" <<'EOF'
#!/bin/sh
{
    echo "curl argc=$#"
    for a in "$@"; do printf '  arg: %s\n' "$a"; done
} >> "$STUB_LOG"
exit "${STUB_CURL_RC:-0}"
EOF
cat > "$work/bin/nc" <<'EOF'
#!/bin/sh
{
    printf 'nc %s\n' "$*"
    printf '  data: %s\n' "$(cat)"
} >> "$STUB_LOG"
exit 0
EOF
cat > "$work/bin/logger" <<'EOF'
#!/bin/sh
printf 'logger %s\n' "$*" >> "$STUB_LOG"
EOF
cat > "$work/bin/hostname" <<'EOF'
#!/bin/sh
echo zfs-test-host
EOF
cat > "$work/bin/sleep" <<'EOF'
#!/bin/sh
printf 'sleep %s\n' "$*" >> "$STUB_LOG"
EOF
chmod +x "$work/bin/"*

# ------------------------------------------------------------------ ZED dir
zed="$work/zed.d"
mkdir "$zed"
for f in $lib $zedlets; do
    cp "scripts/$f" "$zed/$f"
    chmod +x "$zed/$f"
done
sed 's/^DD_API_KEY=.*/DD_API_KEY="stub-key-for-tests"/' scripts/config.sh.example > "$zed/config.sh"

# Library-level checks, run from inside the ZED dir so $0 resolves there.
cat > "$zed/lib-driver.sh" <<'EOF2'
#!/bin/sh
# Assignments are made as separate commands, never as prefixes on a function
# call, because whether a prefix assignment outlives the call differs by shell.
. "$(dirname "$0")/zfs-datadog-lib.sh"
title=caller-title tags=caller-tags priority=caller-priority retry=caller-retry
report() { if "$@"; then echo "  rc=0"; else echo "  rc=$?"; fi >> "$STUB_LOG"; }
echo "case: unknown priority falls back to normal, event_type tag appended" >> "$STUB_LOG"
report send_datadog_event "T1" "body" "warning" "a:1,b:2" "urgent" "ereport.fs.zfs.io"
echo "case: low priority, event_type with empty tags" >> "$STUB_LOG"
saved_tags=$DD_TAGS
DD_TAGS=""
report send_datadog_event "T2" "body" "info" "" "low" "pool_import"
DD_TAGS=$saved_tags
echo "case: caller variables and IFS untouched" >> "$STUB_LOG"
printf '  %s %s %s %s ifs=%s\n' "$title" "$tags" "$priority" "$retry" \
    "$(printf '%s' "$IFS" | od -An -c | tr -s ' ')" >> "$STUB_LOG"
echo "case: curl fails on every attempt" >> "$STUB_LOG"
STUB_CURL_RC=7
export STUB_CURL_RC
report send_datadog_event "T3" "body" "error" "x:y"
unset STUB_CURL_RC
echo "case: missing API key" >> "$STUB_LOG"
saved_key=$DD_API_KEY
DD_API_KEY=""
report send_datadog_event "T4" "body"
DD_API_KEY=$saved_key
echo "case: metric with and without tags" >> "$STUB_LOG"
report send_metric "zfs.test.gauge" 5 gauge "k:v"
report send_metric "zfs.test.count" 1 counter ""
echo "case: health and alert mapping" >> "$STUB_LOG"
for s in ONLINE degraded FAULTED offline UNAVAIL removed bogus; do
    printf '  %s -> %s %s\n' "$s" "$(get_pool_health_value "$s")" "$(get_alert_type "$s")" >> "$STUB_LOG"
done
echo "case: build_tags" >> "$STUB_LOG"
printf '  %s\n' "$(build_tags)" >> "$STUB_LOG"
EOF2
chmod +x "$zed/lib-driver.sh"

# -------------------------------------------------------------------- runner
run_suite() {
    sh_under_test=$1
    out=$2
    : > "$out"
    export STUB_LOG="$out"
    for script in lib-driver.sh $zedlets; do
        case "$script" in
            *checksum*) class=ereport.fs.zfs.checksum ;;
            *io*) class=ereport.fs.zfs.io ;;
            all-datadog.sh) class=ereport.fs.zfs.checksum ;;
            *-datadog.sh) class=sysevent.fs.zfs.${script%-datadog.sh} ;;
            *) class=none ;;
        esac
        echo "=== $script ($class)" >> "$out"
        rc=0
        env -i PATH="$work/bin:/usr/bin:/bin" STUB_LOG="$out" HOME="$work" \
            HOSTNAME=zfs-test-host \
            ZEVENT_CLASS="$class" ZEVENT_SUBCLASS="${class##*.}" ZEVENT_EID=42 \
            ZEVENT_TIME="1700000000 0" ZEVENT_POOL=tank ZEVENT_POOL_GUID=123 \
            ZEVENT_VDEV_PATH=/dev/da1 ZEVENT_VDEV_STATE=DEGRADED \
            ZEVENT_VDEV_STATE_STR=DEGRADED ZEVENT_POOL_STATE_STR=DEGRADED \
            ZEVENT_VDEV_CKSUM_ERRORS=3 ZEVENT_VDEV_READ_ERRORS=1 \
            ZEVENT_VDEV_WRITE_ERRORS=2 ZEVENT_POOL_SCRUB_ERRORS=4 \
            ZEVENT_POOL_SCRUB_START=1700000000 ZEVENT_POOL_SCRUB_END=1700007384 \
            ZEVENT_POOL_RESILVER_ERRORS=0 ZEVENT_POOL_RESILVER_START=1700000000 \
            ZEVENT_POOL_RESILVER_END=1700000600 \
            "$sh_under_test" "$zed/$script" > /dev/null 2>&1 || rc=$?
        echo "--- exit $rc" >> "$out"
    done
}

shells=${*:-sh}
if [ $# -eq 0 ]; then
    for extra in dash bash; do
        command -v "$extra" > /dev/null 2>&1 && shells="$shells $extra"
    done
fi

fail=0
for s in $shells; do
    run_suite "$s" "$work/transcript.$s"
    if [ -n "${ZEDLET_PAYLOADS_WRITE:-}" ]; then
        cp "$work/transcript.$s" "$ZEDLET_PAYLOADS_WRITE"
        echo "wrote $ZEDLET_PAYLOADS_WRITE using $s"
        exit 0
    fi
    if diff -u "$golden" "$work/transcript.$s"; then
        echo "ok    $s: transcript matches $golden"
    else
        echo "FAIL  $s: transcript differs from $golden (diff above)"
        fail=1
    fi
done
exit "$fail"
