#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic transports only. No config, inherited secrets, network or ZFS tools.
use std/assert

def check-case [root: path, shell: path, failures: list<bool>, retry: bool, enabled: string] {
    let case = (mktemp -d)
    try {
        let bin = ($case | path join bin)
        mkdir $bin
        cp ($root | path join scripts/resilver_start-datadog.sh) $case
        cp ($root | path join scripts/zfs-datadog-lib.sh) $case
        # Only these inert utilities are available to the child shell.
        for tool in [dirname cut cat basename] {
            ^ln -s (which $tool | first | get path) ($bin | path join $tool)
        }
        let stub = r#'
use std/assert
 def main --wrapped [...args: string] {
    let input = ($in | default '' | into string)
    let log = ($env.HOME | path join calls.jsonl)
    let old = (if ($log | path exists) { open --raw $log | lines | each { from json } } else { [] })
    {tool: $tool, args: $args, input: $input} | to json --raw | $in + "\n" | save --append $log
    if $tool == 'date' { print '2000-01-01 00:00:00'; return }
    if $tool in ['logger' 'sleep'] { return }
    let sender = (if $tool == 'curl' { 2 } else if ($input | str starts-with 'zfs.resilver.start:') { 0 } else { 1 })
    let prior = ($old | where tool == $tool | where {|x| $tool == 'curl' or $x.input == $input } | length)
    let fail = (($env.FAILURES | from json | get $sender) or ($env.RETRY == 'true' and $prior == 0))
    if $tool == 'curl' { print -n '202' }
    if $fail { exit 1 }
 }
'#
        for tool in [nc curl logger sleep date] {
            let content = ($'#!($nu.current-exe) --stdin' + "\nconst tool = '" + $tool + "'\n" + $stub)
            $content | save ($bin | path join $tool)
            ^chmod +x ($bin | path join $tool)
        }
        let result = (^env -i $'PATH=($bin)' $'HOME=($case)' 'HOSTNAME=synthetic-host' 'DD_API_KEY=synthetic-key' 'DD_API_URL=https://synthetic.invalid' 'DOGSTATSD_HOST=synthetic.invalid' 'DOGSTATSD_PORT=18125' 'DD_TAGS=env:test,team:storage' 'ZEVENT_POOL=synthetic-pool' 'ZEVENT_TIME=1234567890' 'ZEVENT_EID=42' 'ZEVENT_VDEV_PATH=/synthetic/disk-test' 'ZEVENT_VDEV_STATE=ONLINE' $'MONITOR_RESILVER=($enabled)' $'FAILURES=($failures | to json --raw)' $'RETRY=($retry)' $shell ($case | path join resilver_start-datadog.sh) | complete)
        let calls = (if ($case | path join calls.jsonl | path exists) { open --raw ($case | path join calls.jsonl) | lines | each { from json } } else { [] })
        if $enabled != 'true' {
            assert equal $result.exit_code 0
            assert equal $result.stdout ''
            assert equal $result.stderr ''
            assert equal $calls []
        } else {
            let failed = ($failures | any {|x| $x })
            assert equal $result.exit_code (if $failed { 1 } else { 0 })
            assert equal $result.stdout ''
            assert equal ($result.stderr | str contains '[ERROR] Resilver start sender failure: pool=synthetic-pool eid=42') $failed
            assert equal ($result.stderr | str contains '[INFO] Resilver start event processed: pool=synthetic-pool eid=42') (not $failed)
            let tags = 'env:test,team:storage,pool:synthetic-pool,vdev:disk-test,vdev_state:ONLINE'
            let payloads = [ $'zfs.resilver.start:1|c|#($tags),host:synthetic-host' $'zfs.resilver.in_progress:1|g|#($tags),host:synthetic-host' ]
            let transports = ($calls | where {|x| $x.tool in ['nc' 'curl'] })
            mut expected = []
            mut sleeps = []
            for i in 0..2 {
                let count = (if ($failures | get $i) { if $i == 2 { 3 } else { 2 } } else if $retry { 2 } else { 1 })
                for attempt in 1..$count { $expected = ($expected | append $i) }
                if $count > 1 { $sleeps = ($sleeps | append '1') }
                if $count == 3 { $sleeps = ($sleeps | append '2') }
            }
            assert equal ($transports | each {|x| if $x.tool == 'curl' { 2 } else if $x.input == ($payloads | first) { 0 } else { 1 } }) $expected
            for x in $transports {
                if $x.tool == 'nc' {
                    assert ($x.input in $payloads)
                    assert equal $x.args ['-u' '-w1' 'synthetic.invalid' '18125']
                } else {
                    let args = (if ($x.args | first 5) == ['-s' '-o' '/dev/null' '-w' '%{http_code}'] { ['-s' ...($x.args | skip 5)] } else { $x.args })
                    assert equal ($args | first 10) ['-s' '-m' '10' '-X' 'POST' 'https://synthetic.invalid/api/v1/events' '-H' 'Content-Type: application/json' '-H' 'DD-API-KEY: synthetic-key']
                    assert equal ($args | get 10) '-d'
                    assert equal ($args | length) 12
                    assert equal ($args | last | from json) {
                        title: 'ZFS Resilver Started: synthetic-pool', text: "Pool: synthetic-pool\nEvent ID: 42\nStarted at: 1234567890",
                        priority: normal, tags: ($tags | split row ','), alert_type: warning, source_type_name: zfs, host: synthetic-host
                    }
                }
            }
            assert equal ($calls | where tool == sleep | each {|x| $x.args | first }) $sleeps
            let logs = ($calls | where tool == logger | each {|x| assert equal ($x.args | first 2) ['-t' 'zfs-datadog']; $x.args | last })
            assert equal ($logs | length) ($result.stderr | lines | length)
            for line in $logs { assert ($result.stderr | str contains $line) }
            for i in 0..1 {
                assert equal ($result.stderr | str contains $'Failed to send metric after 2 attempts: ($payloads | get $i)') ($failures | get $i)
            }
            assert equal ($result.stderr | str contains 'Failed to send event after 3 attempts') ($failures | get 2)
            let event_attempts = ($expected | where {|x| $x == 2 } | length)
            assert equal ($result.stderr | lines | where {|x| $x | str contains '[WARN] Failed to send event (attempt' } | length) ($event_attempts - 1)
            assert equal ($result.stderr | str contains 'Event sent to Datadog: ZFS Resilver Started: synthetic-pool') (not ($failures | get 2))
            for i in 0..1 {
                assert equal ($result.stderr | str contains $'[DEBUG] Metric sent: ($payloads | get $i)') (not ($failures | get $i))
            }
        }
    } catch {|err|
        rm -rf $case
        error make {msg: $'($shell) failures=($failures) retry=($retry) enabled=($enabled): ($err.msg)'}
    }
    rm -rf $case
}

def main [] {
    let root = ($env.FILE_PWD | path join ../.. | path expand)
    for name in [sh dash bash] {
        let found = (which $name)
        assert (not ($found | is-empty)) $'Required shell unavailable: ($name)'
        let shell = ($found | first | get path)
        for a in [false true] { for b in [false true] { for c in [false true] {
            for retry in [false true] { check-case $root $shell [$a $b $c] $retry 'true' }
        } } }
        for enabled in ['false' '' 'TRUE'] { check-case $root $shell [true true true] false $enabled }
        print $'PASS ($name): 16 sender/retry cases and 3 disabled cases'
    }
}
