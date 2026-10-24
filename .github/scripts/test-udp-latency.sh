#!/bin/sh
# Real-nc latency and delivery regression for the DogStatsD handoff.
#
# FreeBSD nc and OpenBSD/Debian nc keep waiting -w seconds after stdin EOF on
# a UDP send to a live receiver, so with -w1 every datagram cost about a
# second (a three-datagram zedlet took three). This starts a throwaway nc
# listener on a loopback port, sends one metric through zfs-datadog-lib.sh
# with the real nc (no stub), and requires it to arrive intact at the
# listener. Four rounds, each with a fresh listener, must take two seconds
# or less in total; at -w1 each round takes a second or more.
#
# The listener is `nc -u -l 127.0.0.1 PORT`, the BSD and OpenBSD form. A
# netcat that does not understand it (GNU netcat-traditional wants -p) makes
# the test skip.
#
# Usage: .github/scripts/test-udp-latency.sh
#   Skips (exit 0) when nc or the listener form is unavailable unless
#   UDP_LATENCY_REQUIRE_NC=1.
set -eu
cd "$(git rev-parse --show-toplevel)"

port=18987
rounds=4
skip() {
    if [ "${UDP_LATENCY_REQUIRE_NC:-0}" = 1 ]; then
        echo "FAIL  $1" >&2
        exit 1
    fi
    echo "skip  $1"
    exit 0
}
command -v nc > /dev/null 2>&1 || skip "nc is not installed"

work=$(mktemp -d)
listener=''
stop_listener() {
    if [ -n "$listener" ]; then
        kill "$listener" 2> /dev/null || true
        wait "$listener" 2> /dev/null || true
        listener=''
    fi
}
trap 'stop_listener; rm -rf "$work"' EXIT
mkdir "$work/bin"
# The lib logs through logger; keep the test out of the host's syslog.
printf '#!/bin/sh\nexit 0\n' > "$work/bin/logger"
chmod +x "$work/bin/logger"
cp scripts/zfs-datadog-lib.sh "$work/zfs-datadog-lib.sh"
cp scripts/config.sh.example "$work/config.sh"
cat > "$work/driver.sh" <<'EOF2'
#!/bin/sh
. "$(dirname "$0")/zfs-datadog-lib.sh"
send_metric zfs.test.latency 1 counter "k:v"
EOF2

total=0
fail=0
round=0
while [ "$round" -lt "$rounds" ]; do
    round=$((round + 1))
    : > "$work/received"
    nc -u -l 127.0.0.1 "$port" > "$work/received" 2> /dev/null &
    listener=$!
    sleep 1
    kill -0 "$listener" 2> /dev/null || skip "nc cannot listen with 'nc -u -l 127.0.0.1 $port'"
    start=$(date +%s)
    PATH="$work/bin:$PATH" DOGSTATSD_PORT="$port" sh "$work/driver.sh" 2> /dev/null || {
        echo "FAIL  round $round: send_metric failed" >&2
        fail=1
    }
    end=$(date +%s)
    total=$((total + end - start))
    sleep 1
    if ! grep -F 'zfs.test.latency:1|c|#k:v' "$work/received" > /dev/null; then
        echo "FAIL  round $round: the datagram did not reach the listener" >&2
        fail=1
    fi
    stop_listener
done

if [ "$total" -gt 2 ]; then
    echo "FAIL  $rounds sends took ${total}s in total; nc is blocking after EOF (expected <= 2s)" >&2
    fail=1
fi
if [ "$fail" -eq 0 ]; then
    echo "ok    $rounds datagrams delivered in ${total}s total with $(command -v nc)"
fi
exit "$fail"
