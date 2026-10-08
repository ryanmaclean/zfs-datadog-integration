#!/bin/sh
# Golden-output regression test for everything scripts/install.sh ships.
#
# Every zedlet named in install.sh, plus the shared library, is copied into a
# throwaway ZED directory and run against fixed ZEVENT_* inputs. nc, logger,
# and hostname are replaced by recording stubs, so the exact Agent-local
# DogStatsD event and metric datagrams are captured without network access.
# The transcript must match .github/tests/zedlet-payloads.golden byte for byte.
#
# Usage: .github/scripts/test-zedlet-payloads.sh [shell ...]
#   Each shell (default: sh, plus dash and bash when installed) runs the full
#   suite; every run must produce the golden transcript.
#   Set ZEDLET_PAYLOADS_WRITE=path to write a reviewable candidate transcript
#   instead of comparing; update the golden only after reviewing its bytes.
set -eu
cd "$(git rev-parse --show-toplevel)"

golden=.github/tests/zedlet-payloads.golden
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# ---------------------------------------------------------------- shipped set
# Parse all shipped sources from install.sh. HANDLERS are installed under
# hidden names and reached only through the enabled ereport wrappers.
lib=$(sed -n "s/^LIB='\\(.*\\)'\$/\\1/p" scripts/install.sh)
zedlets=$(sed -n "/^ZEDLETS='/,/'\$/p" scripts/install.sh | tr -d "'" | sed 's/^ZEDLETS=//')
handlers=$(sed -n "s/^HANDLERS='\\(.*\\)'\$/\\1/p" scripts/install.sh)
if [ -z "$lib" ] || [ -z "$zedlets" ] || [ -z "$handlers" ]; then
    echo "Could not read LIB/ZEDLETS/HANDLERS from scripts/install.sh" >&2
    exit 1
fi

# --------------------------------------------------------------------- stubs
mkdir "$work/bin"
cat > "$work/bin/nc" <<'EOF'
#!/bin/sh
{
    printf 'nc %s\n' "$*"
    printf '  data: %s\n' "$(cat)"
} >> "$STUB_LOG"
exit "${STUB_NC_RC:-0}"
EOF
cat > "$work/bin/logger" <<'EOF'
#!/bin/sh
printf 'logger %s\n' "$*" >> "$STUB_LOG"
EOF
cat > "$work/bin/hostname" <<'EOF'
#!/bin/sh
echo zfs-test-host
EOF
chmod +x "$work/bin/"*

# ------------------------------------------------------------------ ZED dir
zed="$work/zed.d"
mkdir "$zed"
for f in $lib $zedlets; do
    cp "scripts/$f" "$zed/$f"
    chmod +x "$zed/$f"
done
for f in $handlers; do
    cp "scripts/$f" "$zed/.$f"
    chmod +x "$zed/.$f"
done
for forbidden in all-datadog.sh checksum-error.sh io-error.sh; do
    if [ -e "$zed/$forbidden" ] || [ -L "$zed/$forbidden" ]; then
        echo "Unexpected active route: $forbidden" >&2
        exit 1
    fi
done
cp scripts/config.sh.example "$zed/config.sh"

# Library-level checks, run from inside the ZED dir so $0 resolves there.
cat > "$zed/lib-driver.sh" <<'EOF2'
#!/bin/sh
# Assignments are made as separate commands, never as prefixes on a function
# call, because whether a prefix assignment outlives the call differs by shell.
. "$(dirname "$0")/zfs-datadog-lib.sh"
title=caller-title tags=caller-tags priority=caller-priority retry=caller-retry
report() { if "$@"; then echo "  rc=0"; else echo "  rc=$?"; fi >> "$STUB_LOG"; }
echo "case: unknown priority fails closed" >> "$STUB_LOG"
report send_datadog_event "T1" "body" "warning" "a:1,b:2" "urgent" "ereport.fs.zfs.io"
echo "case: low priority, event_type with empty tags" >> "$STUB_LOG"
saved_tags=$DD_TAGS
DD_TAGS=""
report send_datadog_event "T2" "body" "info" "" "low" "pool_import"
DD_TAGS=$saved_tags
echo "case: caller variables and IFS untouched" >> "$STUB_LOG"
printf '  %s %s %s %s ifs=%s\n' "$title" "$tags" "$priority" "$retry" \
    "$(printf '%s' "$IFS" | od -An -c | tr -s ' ')" >> "$STUB_LOG"
echo "case: local socket failure is returned after one attempt" >> "$STUB_LOG"
STUB_NC_RC=7
export STUB_NC_RC
report send_datadog_event "T3" "body" "error" "x:y"
unset STUB_NC_RC
echo "case: remote endpoint rejected before sending" >> "$STUB_LOG"
saved_host=$DOGSTATSD_HOST
DOGSTATSD_HOST=192.0.2.1
report send_datadog_event "T4" "body"
DOGSTATSD_HOST=$saved_host
echo "case: wire delimiter in title rejected" >> "$STUB_LOG"
report send_datadog_event 'T|5' "body"
echo "case: tag delimiter rejected" >> "$STUB_LOG"
report send_metric "zfs.test.bad" 1 gauge 'pool:tank|p:low'
echo "case: metric with and without tags" >> "$STUB_LOG"
report send_metric "zfs.test.gauge" 5 gauge "k:v"
report send_metric "zfs.test.count" 1 counter ""
echo "case: health and alert mapping" >> "$STUB_LOG"
for s in ONLINE degraded FAULTED offline UNAVAIL removed bogus; do
    printf '  %s -> %s %s\n' "$s" "$(get_pool_health_value "$s")" "$(get_alert_type "$s")" >> "$STUB_LOG"
done
echo "case: build_tags" >> "$STUB_LOG"
printf '  %s\n' "$(build_tags)" >> "$STUB_LOG"
echo "case: invalid pool tag rejected" >> "$STUB_LOG"
ZEVENT_POOL='tank,host:forged'
report build_tags
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
        if [ "$rc" -ne 0 ]; then
            printf 'FAIL  %s: successful socket stub returned exit=%s\n' "$script" "$rc" >&2
            fail=1
        fi
        [ "$script" = lib-driver.sh ] && continue

        # Every active route must propagate a failed local socket handoff.
        # The count also proves a failure does not suppress the later metrics
        # of a multi-signal ZFS event or retry any one datagram ambiguously.
        case "$script" in
            statechange-datadog.sh|ereport.fs.zfs.checksum-datadog.sh) expected=2 ;;
            scrub_start-datadog.sh|resilver_start-datadog.sh) expected=3 ;;
            scrub_finish-datadog.sh|resilver_finish-datadog.sh|ereport.fs.zfs.io-datadog.sh) expected=4 ;;
            *) expected=1 ;;
        esac
        echo "=== failed-nc $script ($class)" >> "$out"
        before=$(wc -l < "$out")
        rc=0
        env -i PATH="$work/bin:/usr/bin:/bin" STUB_LOG="$out" STUB_NC_RC=7 HOME="$work" \
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
        sends=$(awk -v first="$((before + 1))" 'NR >= first && /^nc / { count++ } END { print count + 0 }' "$out")
        printf '%s\n' "--- failed-nc exit $rc sends $sends expected $expected" >> "$out"
        if [ "$rc" -ne 1 ] || [ "$sends" -ne "$expected" ]; then
            printf 'FAIL  %s: failed nc exit=%s sends=%s expected=%s\n' \
                "$script" "$rc" "$sends" "$expected" >&2
            fail=1
        fi
        case "$script" in
            ereport.fs.zfs.checksum-datadog.sh)
                if ! awk -v first="$((before + 1))" 'NR >= first && /^  data: zfs[.]checksum[.]errors:/ { found=1 } END { exit !found }' "$out"; then
                    printf 'FAIL  checksum wrapper did not reach hidden handler\n' >&2
                    fail=1
                fi ;;
            ereport.fs.zfs.io-datadog.sh)
                if ! awk -v first="$((before + 1))" 'NR >= first && /^  data: zfs[.]io[.]error:/ { found=1 } END { exit !found }' "$out"; then
                    printf 'FAIL  I/O wrapper did not reach hidden handler\n' >&2
                    fail=1
                fi ;;
        esac
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
        [ "$fail" -eq 0 ] || exit 1
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
