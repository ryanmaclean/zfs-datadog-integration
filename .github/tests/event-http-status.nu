#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Run from the repository root. All side effects stay in a temporary directory;
# shell functions replace curl, sleep and logging (no executable stub files).
def main [] {
    let library = (pwd | path join scripts zfs-datadog-lib.sh)
    let work = (^mktemp -d | str trim)
    let driver = '
. "$1"
log_message() { printf "%s: %s\n" "$1" "$2" >&2; }
sleep() { printf "sleep %s\n" "$1" >> "$TRACE"; }
curl() {
    printf "curl\n" >> "$TRACE"
    # Always return the supplied HTTP status independently of curl --fail.
    # Auth failures and redirects can otherwise look like successful transport.
    status=$(head -n 1 "$STATUSES")
    tail -n +2 "$STATUSES" > "$STATUSES.next"
    mv "$STATUSES.next" "$STATUSES"
    write_status=0
    discard_body=0
    for arg in "$@"; do
        [ "$arg" != "%{http_code}" ] || write_status=1
        [ "$arg" != /dev/null ] || discard_body=1
    done
    printf "sensitive-diagnostic-stub-key-for-tests\n" >&2
    if [ "$discard_body" -eq 0 ]; then
        printf "sensitive-response-body\n"
    fi
    [ "$write_status" -eq 0 ] || printf "%s" "${status%%:*}"
    case "$status" in
        transport|204:7) return 7 ;;
        *) return 0 ;;
    esac
}
send_datadog_event "HTTP regression" "stub body"
'
    let cases = [
        {name: ok_200, statuses: "200\n", rc: 0, trace: "curl\n", success: true}
        {name: ok_202, statuses: "202\n", rc: 0, trace: "curl\n", success: true}
        {name: ok_204, statuses: "204\n", rc: 0, trace: "curl\n", success: true}
        {name: ok_299, statuses: "299\n", rc: 0, trace: "curl\n", success: true}
        {name: redirect, statuses: "302\n302\n302\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: client_error, statuses: "400\n400\n400\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: unauthorized, statuses: "401\n401\n401\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: proxy_auth, statuses: "407\n407\n407\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: not_found, statuses: "404\n404\n404\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: server_error, statuses: "500\n500\n500\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: invalid, statuses: "invalid\ninvalid\ninvalid\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: malformed_2xx, statuses: "200x\n200x\n200x\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: short_status, statuses: "20\n20\n20\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: missing, statuses: "\n\n\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: no_http, statuses: "000\n000\n000\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: transport_failure, statuses: "transport\ntransport\ntransport\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: transport_with_2xx, statuses: "204:7\n204:7\n204:7\n", rc: 1, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: false}
        {name: recovery, statuses: "transport\n401\n204\n", rc: 0, trace: "curl\nsleep 1\ncurl\nsleep 2\ncurl\n", success: true}
    ]
    mut failures = 0
    for case in $cases {
        let trace = ($work | path join trace)
        let statuses = ($work | path join statuses)
        '' | save -f $trace
        $case.statuses | save -f $statuses
        let result = (^env -i PATH=/usr/bin:/bin DD_API_KEY=stub-key-for-tests HOSTNAME=stub-host $"TRACE=($trace)" $"STATUSES=($statuses)" sh -c $driver ($work | path join driver) $library | complete)
        let recorded = (open --raw $trace)
        let delivered = ($result.stderr | str contains 'Event sent to Datadog:')
        let exhausted = ($result.stderr | str contains 'Failed to send event after 3 attempts')
        let leaked = ($result.stderr | str contains 'sensitive-') or ($result.stderr | str contains 'stub-key-for-tests') or ($result.stdout | str contains 'sensitive-')
        if (not $leaked and $result.exit_code == $case.rc and $recorded == $case.trace and $delivered == $case.success and $exhausted == (not $case.success)) {
            print $"PASS ($case.name): exit=($result.exit_code), retry trace and delivery log verified"
        } else {
            print $"FAIL ($case.name): exit=($result.exit_code) expected=($case.rc), trace=($recorded | to nuon), stderr=($result.stderr | to nuon)"
            $failures = $failures + 1
        }
    }
    rm -r $work
    if $failures > 0 { error make {msg: $"($failures) HTTP regression cases failed"} }
}
