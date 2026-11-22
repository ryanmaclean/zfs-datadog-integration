#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic inputs, private config, allowlisted PATH: no real transport or ZFS.
# One event datagram and one metric datagram go to the loopback Agent; the
# sender never retries or sleeps.
use std/assert
use datagram.nu *

def check-case [work: path, shell: string, event: int, metric: int, enabled: bool, vdev: bool] {
    let log = ($work | path join calls.jsonl)
    '' | save -f $log
    let result = (^env -i $'PATH=($work)/bin' $'HOME=($work)' $'CALL_LOG=($log)'
        $'EVENT_RC=($event)' $'METRIC_RC=($metric)' HOSTNAME=synthetic-host
        $'MONITOR_POOL_HEALTH=($enabled)' ZEVENT_POOL=synthetic-pool ZEVENT_VDEV_STATE=DEGRADED
        $'ZEVENT_VDEV_PATH=(if $vdev { "/synthetic/disk-one" } else { "" })'
        $shell ($work | path join statechange-datadog.sh) | complete)
    let calls = (open --raw $log | lines | each { from json })
    let sends = ($calls | where kind in [curl nc sleep])
    if not $enabled {
        assert equal $result.exit_code 0
        assert equal ($calls | length) 0
        return
    }
    # Exactly one event then one metric; no curl, no retry, no sleep.
    assert equal ($sends | get kind) [nc nc]
    let tags = (['env:fixture' 'pool:synthetic-pool']
        | append (if $vdev { ['vdev:disk-one'] } else { [] }) | append 'vdev_state:DEGRADED')
    let title = $'ZFS Pool Health Change: synthetic-pool(if $vdev { " (vdev: disk-one)" } else { "" })'
    let text = (if $vdev { 'Pool: synthetic-pool\nVdev: disk-one\nNew State: DEGRADED\nPath: /synthetic/disk-one' } else { 'Pool: synthetic-pool\nNew State: DEGRADED' })
    for call in $sends {
        assert equal $call.args ['-u' '-w1' '127.0.0.1' '18125']
    }
    assert (datagram is-event $sends.0.stdin)
    assert equal (datagram event $sends.0.stdin) {title: $title, text: $text, priority: normal, alert_type: warning, source: zfs, tags: $tags}
    assert (not (datagram is-event $sends.1.stdin))
    assert equal $sends.1.stdin $'zfs.pool.health:1|g|#($tags | str join ",")'
    let failed = ($event != 0 or $metric != 0)
    assert equal $result.exit_code (if $failed { 1 } else { 0 })
    assert equal ($result.stderr | str contains '[ERROR] Pool health submission failed: synthetic-pool - DEGRADED') $failed
    assert equal ($result.stderr | str contains '[ERROR] Local Agent event handoff failed') ($event != 0)
    assert equal ($result.stderr | str contains '[ERROR] Local Agent metric handoff failed') ($metric != 0)
    assert equal ($result.stderr | str contains '[INFO] Pool health event processed: synthetic-pool - DEGRADED') (not $failed)
}

def main [] {
    let root = ($env.FILE_PWD | path join ../.. | path expand)
    let work = (^mktemp -d | str trim)
    try {
        mkdir ($work | path join bin)
        cp ($root | path join scripts/statechange-datadog.sh) $work
        cp ($root | path join scripts/zfs-datadog-lib.sh) $work
        'DD_TAGS="env:fixture"
DOGSTATSD_HOST="127.0.0.1"
DOGSTATSD_PORT="18125"
' | save ($work | path join config.sh)
        # Only known, harmless utilities are available to the shell and its library.
        for name in [dirname basename cat cut tr date wc] {
            ^ln -s ((which --all $name | where type == external | first).path) ($work | path join bin $name)
        }
        let shebang = $'#!($nu.current-exe) --no-config-file(char newline)'
        let stub = 'def --wrapped main [...args: string] {
    let kind = ($env.CURRENT_FILE | path basename)
    let data = (if $kind == "nc" { open --raw /dev/stdin } else { "" })
    ({kind: $kind, args: $args, stdin: $data} | to json -r) + (char newline) | save --append $env.CALL_LOG
    if $kind == "nc" {
        let rc = (if ($data | str starts-with "_e{") { $env.EVENT_RC } else { $env.METRIC_RC })
        exit ($rc | into int)
    }
}
'
        for name in [curl nc logger sleep] {
            let target = ($work | path join bin $name)
            ($shebang + $stub) | save $target
            ^chmod +x $target
        }
        for shell in [sh dash bash] {
            let executable = (which $shell | first | get path)
            for event in [0 7] {
                for metric in [0 9] {
                    for vdev in [true false] {
                        check-case $work $executable $event $metric true $vdev
                    }
                }
            }
            check-case $work $executable 7 9 false true
            print $'PASS ($shell): 8 delivery cases and disabled early exit'
        }
        # Mutation oracle: a zedlet that swallows sender failures must be rejected.
        let original = (open --raw ($root | path join scripts/statechange-datadog.sh))
        let mutated = ($original | str replace --all 'exit 1' 'exit 0')
        assert ($mutated != $original) 'mutation did not apply'
        $mutated | save -f ($work | path join statechange-datadog.sh)
        check-case $work (which sh | first | get path) 0 0 true true
        let rejected = (try { check-case $work (which sh | first | get path) 7 9 true true; false } catch { true })
        assert $rejected 'Mutated zedlet unexpectedly passed failure oracle'
        print 'PASS mutated behavior rejected by failure oracle'
    } catch {|err|
        rm -rf $work
        error make {msg: ($err.rendered? | default $err.msg)}
    }
    rm -rf $work
}
