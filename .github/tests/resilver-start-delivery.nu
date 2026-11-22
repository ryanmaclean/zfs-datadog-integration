#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic transports only. No config, inherited secrets, network or ZFS tools.
use std/assert
use datagram.nu *

# failures: [start metric, in_progress metric, event] forced to fail.
# first_fails: every datagram's first (and only) attempt fails. The library
# never retries, so this must make every send fail rather than recover.
def check-case [root: path, shell: path, failures: list<bool>, first_fails: bool, enabled: string] {
    let case = (mktemp -d)
    try {
        let bin = ($case | path join bin)
        mkdir $bin
        cp ($root | path join scripts/resilver_start-datadog.sh) $case
        cp ($root | path join scripts/zfs-datadog-lib.sh) $case
        # Only these inert utilities are available to the child shell.
        for tool in [dirname cut cat basename wc] {
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
    if $tool in ['logger' 'sleep' 'curl'] { return }
    let sender = (if ($input | str starts-with '_e{') { 2 } else if ($input | str starts-with 'zfs.resilver.start:') { 0 } else { 1 })
    let prior = ($old | where tool == $tool | where {|x| $x.input == $input } | length)
    let fail = (($env.FAILURES | from json | get $sender) or ($env.FIRST_FAILS == 'true' and $prior == 0))
    if $fail { exit 1 }
 }
'#
        for tool in [nc curl logger sleep date] {
            let content = ($'#!($nu.current-exe) --stdin' + "\nconst tool = '" + $tool + "'\n" + $stub)
            $content | save ($bin | path join $tool)
            ^chmod +x ($bin | path join $tool)
        }
        let result = (^env -i $'PATH=($bin)' $'HOME=($case)' 'HOSTNAME=synthetic-host' 'DOGSTATSD_HOST=127.0.0.1' 'DOGSTATSD_PORT=18125' 'DD_TAGS=env:test,team:storage' 'ZEVENT_POOL=synthetic-pool' 'ZEVENT_TIME=1234567890' 'ZEVENT_EID=42' 'ZEVENT_VDEV_PATH=/synthetic/disk-test' 'ZEVENT_VDEV_STATE=ONLINE' $'MONITOR_RESILVER=($enabled)' $'FAILURES=($failures | to json --raw)' $'FIRST_FAILS=($first_fails)' $shell ($case | path join resilver_start-datadog.sh) | complete)
        let calls = (if ($case | path join calls.jsonl | path exists) { open --raw ($case | path join calls.jsonl) | lines | each { from json } } else { [] })
        if $enabled != 'true' {
            assert equal $result.exit_code 0
            assert equal $result.stdout ''
            assert equal $result.stderr ''
            assert equal $calls []
        } else {
            # With no retries a first-attempt failure is final for every sender.
            let effective = ($failures | each {|x| $x or $first_fails })
            let failed = ($effective | any {|x| $x })
            assert equal $result.exit_code (if $failed { 1 } else { 0 })
            assert equal $result.stdout ''
            assert equal ($result.stderr | str contains '[ERROR] Resilver start sender failure: pool=synthetic-pool eid=42') $failed
            assert equal ($result.stderr | str contains '[INFO] Resilver start event processed: pool=synthetic-pool eid=42') (not $failed)
            let tags = 'env:test,team:storage,pool:synthetic-pool,vdev:disk-test,vdev_state:ONLINE'
            let payloads = [ $'zfs.resilver.start:1|c|#($tags)' 'zfs.resilver.in_progress:1|g|#env:test,team:storage,pool:synthetic-pool' ]
            # Exactly one nc call per sender, in order: start metric, progress metric, event.
            let transports = ($calls | where {|x| $x.tool in ['nc' 'curl'] })
            assert equal ($transports | each {|x| $x.tool }) ['nc' 'nc' 'nc']
            assert equal ($calls | where tool == sleep | length) 0
            for x in $transports {
                assert equal $x.args ['-u' '-w1' '127.0.0.1' '18125']
            }
            assert equal ($transports | first 2 | get input) $payloads
            assert equal (datagram event ($transports | last | get input)) {
                title: 'ZFS Resilver Started: synthetic-pool', text: 'Pool: synthetic-pool\nEvent ID: 42\nStarted at: 1234567890',
                priority: normal, alert_type: warning, source: zfs, tags: ($tags | split row ',')
            }
            let logs = ($calls | where tool == logger | each {|x| assert equal ($x.args | first 2) ['-t' 'zfs-datadog']; $x.args | last })
            assert equal ($logs | length) ($result.stderr | lines | length)
            for line in $logs { assert ($result.stderr | str contains $line) }
            let metric_failures = ($effective | first 2 | where {|x| $x } | length)
            assert equal ($result.stderr | lines | where {|x| $x | str contains 'Local Agent metric handoff failed' } | length) $metric_failures
            assert equal ($result.stderr | lines | where {|x| $x | str contains '[DEBUG] Metric handed to local Agent socket' } | length) (2 - $metric_failures)
            assert equal ($result.stderr | str contains 'Local Agent event handoff failed') ($effective | get 2)
            assert equal ($result.stderr | str contains 'Event handed to local Agent socket') (not ($effective | get 2))
            assert (not ($result.stderr | str contains 'attempt'))
        }
    } catch {|err|
        rm -r $case
        error make {msg: $'($shell) failures=($failures) first_fails=($first_fails) enabled=($enabled): ($err.msg)'}
    }
    rm -r $case
}

def main [] {
    let root = ($env.FILE_PWD | path join ../.. | path expand)
    for name in [sh dash bash] {
        let found = (which $name)
        assert (not ($found | is-empty)) $'Required shell unavailable: ($name)'
        let shell = ($found | first | get path)
        for a in [false true] { for b in [false true] { for c in [false true] {
            for first_fails in [false true] { check-case $root $shell [$a $b $c] $first_fails 'true' }
        } } }
        for enabled in ['false' '' 'TRUE'] { check-case $root $shell [true true true] false $enabled }
        print $'PASS ($name): 16 sender/first-attempt cases and 3 disabled cases'
    }
}
