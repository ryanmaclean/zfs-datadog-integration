#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Actual completion handlers, synthetic transports, no real config or ZFS calls.
# Events and metrics reach the local Agent as loopback DogStatsD datagrams; a
# recording nc stub captures them and the event datagram is decoded.
use std/assert
use datagram.nu *

def main [] {
    let repo = ($env.FILE_PWD | path join ../.. | path expand)
    let work = (mktemp -d | str trim)
    try {
        let bin = ($work | path join bin)
        mkdir $bin
        for tool in [dirname basename date cat cut wc mktemp rm] {
            ^ln -s (which --all $tool | where type == external | first | get path) ($bin | path join $tool)
        }
        for name in [zfs-datadog-lib.sh scrub_finish-datadog.sh resilver_finish-datadog.sh] {
            cp ($repo | path join scripts $name) $work
        }
        let stub = ($'#!($nu.current-exe) --no-config-file' + "\n" + '
def main --wrapped [...args: string] {
    let tool = ($env.CURRENT_FILE | path basename)
    if $tool == "nc" {
        if $args != ["-u" "-w0" "127.0.0.1" "18125"] { error make {msg: "unexpected nc argv"} }
        (open --raw /dev/stdin) + "\n" | save --append $env.METRICS
    } else if $tool == "sleep" { error make {msg: "unexpected retry"} }
}
')
        for tool in [nc logger sleep] {
            $stub | save ($bin | path join $tool)
            ^chmod +x ($bin | path join $tool)
        }
        let cases = [
            {value: null, expected: unknown}
            {value: '', expected: unknown}
            {value: '0', expected: '0'}
            {value: '42', expected: '42'}
            {value: '00042', expected: '00042'}
            {value: '9999999999999999999', expected: '9999999999999999999'}
            {value: '10000000000000000000', expected: '10000000000000000000'}
            {value: '18446744073709551615', expected: '18446744073709551615'}
            {value: '18446744073709551616', expected: unknown}
            {value: '99999999999999999999', expected: unknown}
            {value: '100000000000000000000', expected: unknown}
            {value: '-1', expected: unknown}
            {value: '+1', expected: unknown}
            {value: '1.5', expected: unknown}
            {value: ' 42', expected: unknown}
            {value: '42 ', expected: unknown}
            {value: '42x', expected: unknown}
            {value: '"injected":true', expected: unknown}
            {value: "42\n43", expected: unknown}
            {value: '$(touch never-run)', expected: unknown}
        ]
        mut count = 0
        for shell in [sh dash bash] {
            let executable = (which $shell | first | get path)
            for scan in [scrub resilver] {
                for case in $cases {
                    let metrics = ($work | path join metrics)
                    '' | save -f $metrics
                    let eid_env = (if $case.value == null { [] } else { [$'ZEVENT_EID=($case.value)'] })
                    let result = (^env -i $'PATH=($bin)' $'TMPDIR=($bin)' HOSTNAME=fixture DD_TAGS=env:test DOGSTATSD_HOST=127.0.0.1 DOGSTATSD_PORT=18125 MONITOR_SCRUB=true MONITOR_RESILVER=true ZEVENT_POOL=tank ZEVENT_POOL_SCRUB_ERRORS=0 ZEVENT_POOL_RESILVER_ERRORS=0 $'METRICS=($metrics)' ...$eid_env $executable ($work | path join $'($scan)_finish-datadog.sh') | complete)
                    let context = $'($shell)/($scan)/($case | to nuon)'
                    assert equal $result.exit_code 0 $'exit: ($context): ($result | to nuon)'
                    assert equal $result.stdout '' $'stdout: ($context): ($result | to nuon)'
                    let lines = (open --raw $metrics | lines)
                    let packets = ($lines | where {|l| datagram is-event $l })
                    assert equal ($packets | length) 1 $'one event datagram: ($context)'
                    let payload = (datagram event ($packets | first))
                    assert equal $payload.text $'Pool: tank\nEvent ID: ($case.expected)\nStatus: completed successfully\nErrors Found: 0\nDuration: unknown' $'payload: ($context): ($payload | to nuon)'
                    assert equal $payload.tags [env:test pool:tank] $'tags: ($context)'
                    let actual_metrics = ($lines | where {|l| not (datagram is-event $l) })
                    assert equal $actual_metrics [$'zfs.($scan).errors:0|g|#env:test,pool:tank' $'zfs.($scan).in_progress:0|g|#env:test,pool:tank'] $'metrics: ($context): ($actual_metrics | to nuon)'
                    $count += 1
                }
            }
        }
        print $'PASS: ($count) actual-handler synthetic event-ID cases across sh/dash/bash'
    } catch {|err| rm -r $work; error make {msg: $err.msg} }
    rm -r $work
}
