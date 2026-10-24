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
# zpool stands in for "zpool status <pool>": it prints the scan line of the
# finished scan matching the zevent subclass, or STUB_ZPOOL_SCAN when set.
cat > "$work/bin/zpool" <<'EOF'
#!/bin/sh
printf 'zpool %s\n' "$*" >> "$STUB_LOG"
[ "$1" = status ] || exit 2
if [ -n "${STUB_ZPOOL_SCAN+x}" ]; then
    scan=$STUB_ZPOOL_SCAN
else
    case "${ZEVENT_SUBCLASS:-}" in
        scrub_finish) scan='scrub repaired 0B in 02:03:04 with 4 errors on Tue Nov 14 22:13:20 2023' ;;
        resilver_finish) scan='resilvered 12.5M in 00:10:00 with 0 errors on Tue Nov 14 22:13:20 2023' ;;
        *) scan='none requested' ;;
    esac
fi
printf '  pool: %s\n state: ONLINE\n  scan: %s\nconfig:\n\n' "$2" "$scan"
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
for forbidden in all-datadog.sh checksum-error.sh io-error.sh data-error.sh; do
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
echo "case: numeric ZED vdev_state mapped like zpool_state_to_name" >> "$STUB_LOG"
saved_state=$ZEVENT_VDEV_STATE
saved_state_str=$ZEVENT_VDEV_STATE_STR
unset ZEVENT_VDEV_STATE_STR
for n in 0 1 2 3 4 5 6 7 8; do
    ZEVENT_VDEV_STATE=$n
    vs=$(zevent_vdev_state)
    printf '  %s -> %s %s %s\n' "$n" "$vs" "$(get_pool_health_value "$vs")" \
        "$(get_alert_type "$vs")" >> "$STUB_LOG"
done
echo "case: ZEVENT_VDEV_STATE_STR preferred over the number" >> "$STUB_LOG"
ZEVENT_VDEV_STATE=5
ZEVENT_VDEV_STATE_STR=FAULTED
printf '  %s\n' "$(build_tags)" >> "$STUB_LOG"
echo "case: no vdev state, no vdev_state tag" >> "$STUB_LOG"
unset ZEVENT_VDEV_STATE ZEVENT_VDEV_STATE_STR
printf '  %s\n' "$(build_tags)" >> "$STUB_LOG"
ZEVENT_VDEV_STATE=$saved_state
ZEVENT_VDEV_STATE_STR=$saved_state_str
echo "case: zpool status scan line parsing" >> "$STUB_LOG"
for scan in \
    'scrub repaired 0B in 00:00:01 with 0 errors on Tue Nov 14 22:13:20 2023' \
    'scrub repaired 1.5M in 2 days 03:04:05 with 206 errors on Tue Nov 14 22:13:20 2023' \
    'resilvered 12.5M in 00:10:00 with 0 errors on Tue Nov 14 22:13:20 2023' \
    'scrub canceled on Tue Nov 14 22:13:20 2023' \
    'scrub in progress since Tue Nov 14 22:13:20 2023' \
    'none requested'; do
    STUB_ZPOOL_SCAN=$scan
    export STUB_ZPOOL_SCAN
    for kind in scrub resilver; do
        if r=$(zpool_scan_result tank "$kind"); then
            printf '  %s: %s\n' "$kind" "$r"
        else
            printf '  %s: rc=1\n' "$kind"
        fi >> "$STUB_LOG"
    done
done
unset STUB_ZPOOL_SCAN
echo "case: invalid pool name never reaches zpool" >> "$STUB_LOG"
report zpool_scan_result 'tank;id' scrub
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
            ereport.fs.zfs.data-datadog.sh) class=ereport.fs.zfs.data ;;
            *checksum*) class=ereport.fs.zfs.checksum ;;
            *io*) class=ereport.fs.zfs.io ;;
            all-datadog.sh) class=ereport.fs.zfs.checksum ;;
            *-datadog.sh) class=sysevent.fs.zfs.${script%-datadog.sh} ;;
            *) class=none ;;
        esac
        echo "=== $script ($class)" >> "$out"
        rc=0
        run_zedlet "$script" "$class" > /dev/null 2>&1 || rc=$?
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
            statechange-datadog.sh|ereport.fs.zfs.checksum-datadog.sh|ereport.fs.zfs.data-datadog.sh) expected=2 ;;
            scrub_start-datadog.sh|resilver_start-datadog.sh) expected=3 ;;
            scrub_finish-datadog.sh|resilver_finish-datadog.sh|ereport.fs.zfs.io-datadog.sh) expected=4 ;;
            *) expected=1 ;;
        esac
        echo "=== failed-nc $script ($class)" >> "$out"
        before=$(wc -l < "$out")
        rc=0
        run_zedlet "$script" "$class" STUB_NC_RC=7 > /dev/null 2>&1 || rc=$?
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
            ereport.fs.zfs.data-datadog.sh)
                if ! awk -v first="$((before + 1))" 'NR >= first && /^  data: zfs[.]data[.]error:/ { found=1 } END { exit !found }' "$out"; then
                    printf 'FAIL  data wrapper did not reach hidden handler\n' >&2
                    fail=1
                fi ;;
        esac
    done

    # ereport.fs.zfs.data (FreeBSD emits one per unreadable block) carries the
    # failed zio's fields and no vdev. Missing, empty, non-numeric or hostile
    # values must become "unknown" and must never reach the wire; the switch
    # in config.sh must silence the zedlet entirely.
    script=ereport.fs.zfs.data-datadog.sh
    class=ereport.fs.zfs.data
    echo "=== data-hostile $script ($class)" >> "$out"
    before=$(wc -l < "$out")
    rc=0
    run_zedlet "$script" "$class" "ZEVENT_ZIO_TYPE=0x1 [RE|AD]" 'ZEVENT_ZIO_ERR=9;7' \
        ZEVENT_ZIO_BLKID=-1 ZEVENT_ZIO_OBJECT= ZEVENT_ZIO_LEVEL=007 > /dev/null 2>&1 || rc=$?
    echo "--- exit $rc" >> "$out"
    if [ "$rc" -ne 0 ]; then
        printf 'FAIL  %s: hostile data fields exit=%s\n' "$script" "$rc" >&2
        fail=1
    fi
    if awk -v first="$((before + 1))" 'NR >= first && /^  data: / && /(RE[|]AD|9;7|-1|007)/ { bad=1 } END { exit !bad }' "$out"; then
        printf 'FAIL  %s: hostile zevent value reached a datagram\n' "$script" >&2
        fail=1
    fi
    echo "=== data-disabled $script ($class)" >> "$out"
    before=$(wc -l < "$out")
    rc=0
    run_zedlet "$script" "$class" MONITOR_DATA_ERRORS=false > /dev/null 2>&1 || rc=$?
    sends=$(awk -v first="$((before + 1))" 'NR >= first && /^nc / { count++ } END { print count + 0 }' "$out")
    echo "--- exit $rc sends $sends" >> "$out"
    if [ "$rc" -ne 0 ] || [ "$sends" -ne 0 ]; then
        printf 'FAIL  %s: MONITOR_DATA_ERRORS=false exit=%s sends=%s\n' "$script" "$rc" "$sends" >&2
        fail=1
    fi

    # A finish zevent whose pool no longer shows a finished scan (a new scan
    # already started, or zpool status failed) must not claim 0 errors.
    for script in scrub_finish-datadog.sh resilver_finish-datadog.sh; do
        class=sysevent.fs.zfs.${script%-datadog.sh}
        echo "=== result-unavailable $script ($class)" >> "$out"
        rc=0
        run_zedlet "$script" "$class" \
            STUB_ZPOOL_SCAN='scrub in progress since Tue Nov 14 22:13:20 2023' \
            > /dev/null 2>&1 || rc=$?
        echo "--- exit $rc" >> "$out"
        if [ "$rc" -ne 0 ]; then
            printf 'FAIL  %s: unavailable scan result exit=%s\n' "$script" "$rc" >&2
            fail=1
        fi
    done
}

# Run one shipped zedlet with the environment a real ZED gives it
# (cmd/zed/zed_event.c): vdev_state is the numeric vdev_state_t with the
# readable name in ZEVENT_VDEV_STATE_STR, ZEVENT_TIME is "seconds nanoseconds"
# plus TIME_SECS and TIME_STRING, and scrub_finish and resilver_finish carry no
# error count or start/end time. Extra NAME=value arguments are added last.
# Usage: run_zedlet script class [NAME=value ...]
run_zedlet() {
    rz_script=$1
    rz_class=$2
    shift 2
    case "$rz_class" in
        ereport.fs.zfs.data)
            # Shaped like a real FreeBSD 15 data ereport (zfs-fleet-1024,
            # fbsd16-test-01): pool and zio_* fields only, no vdev fields.
            env -i PATH="$work/bin:/usr/bin:/bin" STUB_LOG="$out" HOME="$work" \
                HOSTNAME=zfs-test-host \
                ZEVENT_CLASS="$rz_class" ZEVENT_SUBCLASS="$rz_class" ZEVENT_EID=58 \
                ZEVENT_TIME="1700000000 0" ZEVENT_TIME_SECS=1700000000 \
                ZEVENT_TIME_STRING="2023-11-14 22:13:20+0000" \
                ZEVENT_POOL=tank ZEVENT_POOL_GUID=123 \
                ZEVENT_POOL_STATE=0 ZEVENT_POOL_CONTEXT=0 ZEVENT_POOL_FAILMODE=wait \
                ZEVENT_ZIO_ERR=97 "ZEVENT_ZIO_FLAGS=0x8081 [DONT_AGGREGATE CANFAIL IO_RETRY]" \
                "ZEVENT_ZIO_STAGE=0x4000000 [DONE]" "ZEVENT_ZIO_PIPELINE=0x4100000 [READY DONE]" \
                ZEVENT_ZIO_DELAY=0 ZEVENT_ZIO_TIMESTAMP=0 ZEVENT_ZIO_DELTA=0 \
                "ZEVENT_ZIO_TYPE=0x1 [READ]" "ZEVENT_ZIO_PRIORITY=0x0 [SYNC_READ]" \
                ZEVENT_ZIO_OBJSET=54 ZEVENT_ZIO_OBJECT=2 ZEVENT_ZIO_LEVEL=0 \
                ZEVENT_ZIO_BLKID=0 \
                "$@" "$sh_under_test" "$zed/$rz_script"
            ;;
        *)
            env -i PATH="$work/bin:/usr/bin:/bin" STUB_LOG="$out" HOME="$work" \
                HOSTNAME=zfs-test-host \
                ZEVENT_CLASS="$rz_class" ZEVENT_SUBCLASS="${rz_class##*.}" ZEVENT_EID=42 \
                ZEVENT_TIME="1700000000 0" ZEVENT_TIME_SECS=1700000000 \
                ZEVENT_TIME_STRING="2023-11-14 22:13:20+0000" \
                ZEVENT_POOL=tank ZEVENT_POOL_GUID=123 \
                ZEVENT_VDEV_PATH=/dev/da1 ZEVENT_VDEV_STATE=6 \
                ZEVENT_VDEV_STATE_STR=DEGRADED ZEVENT_POOL_STATE_STR=DEGRADED \
                ZEVENT_VDEV_CKSUM_ERRORS=3 ZEVENT_VDEV_READ_ERRORS=1 \
                ZEVENT_VDEV_WRITE_ERRORS=2 \
                "$@" "$sh_under_test" "$zed/$rz_script"
            ;;
    esac
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
