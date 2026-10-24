#!/bin/sh
# Real-nc latency and delivery regression for the DogStatsD handoff.
#
# Latency: FreeBSD nc and OpenBSD/Debian nc keep waiting -w seconds after
# stdin EOF on a UDP send to a live receiver, so with -w1 every datagram cost
# about a second (a three-datagram zedlet took three). The lib uses -w0.
#
# Delivery: with -w0, nc's first poll() of stdin and the network has a zero
# timeout and nc returns when nothing is ready yet (readwrite() in netcat.c:
# "timeout happened" on num_fds == 0). When stdin is the pipe of
# `printf ... | nc -u -w0`, the datagram is silently dropped whenever nc polls
# before printf has written. On a loaded FreeBSD 16 host that dropped 1 to 3
# of every 12 to 20 sends. The lib therefore feeds nc from a regular file,
# which poll() always reports readable.
#
# This starts one keep-listening nc receiver on a loopback port and sends
# metrics through zfs-datadog-lib.sh with the real nc (no stub) in two
# phases. Phase 1 sends ROUNDS metrics back to back on an otherwise idle
# sender; together they must take at most ROUNDS/2 seconds (at -w1 they take
# ROUNDS seconds or more). Phase 2 sends ROUNDS more while HOGS busy loops
# compete for the CPU, because the drop needs the writer to be scheduled
# late. Every datagram of both phases must arrive intact.
#
# The receiver is `nc -u -l -k 127.0.0.1 PORT`, the FreeBSD and OpenBSD form.
# A netcat that does not understand it (GNU netcat-traditional wants -p and
# has no -k; untested) makes the test skip.
#
# Usage: .github/scripts/test-udp-latency.sh
#   UDP_LATENCY_ROUNDS (default 20) and UDP_LATENCY_HOGS (default 4) tune the
#   run. Skips (exit 0) when nc or the listener form is unavailable unless
#   UDP_LATENCY_REQUIRE_NC=1.
set -eu
cd "$(git rev-parse --show-toplevel)"

port=18987
rounds=${UDP_LATENCY_ROUNDS:-20}
hogs=${UDP_LATENCY_HOGS:-4}
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
hog_pids=''
stop_hogs() {
    for p in $hog_pids; do kill "$p" 2> /dev/null || true; done
    for p in $hog_pids; do wait "$p" 2> /dev/null || true; done
    hog_pids=''
}
stop_listener() {
    if [ -n "$listener" ]; then
        kill "$listener" 2> /dev/null || true
        wait "$listener" 2> /dev/null || true
        listener=''
    fi
}
trap 'stop_hogs; stop_listener; rm -rf "$work"' EXIT
mkdir "$work/bin"
# The lib logs through logger; keep the test out of the host's syslog.
printf '#!/bin/sh\nexit 0\n' > "$work/bin/logger"
chmod +x "$work/bin/logger"
cp scripts/zfs-datadog-lib.sh "$work/zfs-datadog-lib.sh"
cp scripts/config.sh.example "$work/config.sh"
cat > "$work/driver.sh" <<'EOF2'
#!/bin/sh
. "$(dirname "$0")/zfs-datadog-lib.sh"
send_metric zfs.test.latency "$1" counter "k:v"
EOF2

: > "$work/received"
nc -u -l -k 127.0.0.1 "$port" > "$work/received" 2> /dev/null &
listener=$!
sleep 1
kill -0 "$listener" 2> /dev/null || skip "nc cannot listen with 'nc -u -l -k 127.0.0.1 $port'"
# Prove the receiver is up before loading the CPU, so a loss below is the
# sender's and not a receiver that was not bound yet.
printf 'ready:1|c\n' > "$work/ready"
nc -u -w1 127.0.0.1 "$port" < "$work/ready" 2> /dev/null || true
sleep 1
grep -F 'ready:1|c' "$work/received" > /dev/null || skip "nc listener on $port received nothing"

send_round() {
    PATH="$work/bin:$PATH" DOGSTATSD_PORT="$port" sh "$work/driver.sh" "$1" 2> /dev/null || {
        echo "FAIL  send of value $1: send_metric failed" >&2
        fail=1
    }
}

fail=0
# Phase 1, latency: an otherwise idle sender. Values 1..ROUNDS.
round=0
start=$(date +%s)
while [ "$round" -lt "$rounds" ]; do
    round=$((round + 1))
    send_round "$round"
done
end=$(date +%s)
total=$((end - start))

# Phase 2, delivery: the same sends while HOGS busy loops compete for the CPU.
# Values 1001..1000+ROUNDS.
i=0
while [ "$i" -lt "$hogs" ]; do
    i=$((i + 1))
    (while :; do :; done) &
    hog_pids="$hog_pids $!"
done
round=0
while [ "$round" -lt "$rounds" ]; do
    round=$((round + 1))
    send_round "$((1000 + round))"
done
stop_hogs
sleep 1
stop_listener

# Datagrams carry no newline, so the receiver output is one concatenated run.
missing=''
for base in 0 1000; do
    round=0
    while [ "$round" -lt "$rounds" ]; do
        round=$((round + 1))
        v=$((base + round))
        grep -F "zfs.test.latency:${v}|c|#k:v" "$work/received" > /dev/null || missing="$missing $v"
    done
done
if [ -n "$missing" ]; then
    echo "FAIL  datagrams lost (values:$missing; 1..$rounds idle, 1001..$((1000 + rounds)) under $hogs CPU hogs)" >&2
    fail=1
fi
if [ "$total" -gt $((rounds / 2)) ]; then
    echo "FAIL  $rounds idle sends took ${total}s in total; nc is blocking after EOF (expected <= $((rounds / 2))s)" >&2
    fail=1
fi
if [ "$fail" -eq 0 ]; then
    echo "ok    $((2 * rounds)) datagrams delivered ($rounds idle in ${total}s, $rounds under $hogs CPU hogs) with $(command -v nc)"
fi
exit "$fail"
