#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic inputs, private config, allowlisted PATH: no real transport or ZFS.
use std/assert

def check-case [work: path, shell: string, event: int, metric: int, enabled: bool, vdev: bool] {
    let log = ($work | path join calls.jsonl)
    '' | save -f $log
    let result = (^env -i $'PATH=($work)/bin' $'HOME=($work)' $'CALL_LOG=($log)'
        $'EVENT_RC=($event)' $'METRIC_RC=($metric)' HOSTNAME=synthetic-host
        $'MONITOR_POOL_HEALTH=($enabled)' ZEVENT_POOL=synthetic-pool ZEVENT_VDEV_STATE=DEGRADED
        $'ZEVENT_VDEV_PATH=(if $vdev { "/synthetic/disk-one" } else { "" })'
        $shell ($work | path join statechange-datadog.sh) | complete)
    let calls = (open --raw $log | lines | each { from json })
    let sends = ($calls | where kind in [curl nc])
    if not $enabled {
        assert equal $result.exit_code 0
        assert equal ($calls | length) 0
        return
    }
    let curl_calls = ($sends | where kind == curl)
    let nc_calls = ($sends | where kind == nc)
    assert equal ($curl_calls | length) (if $event == 0 { 1 } else { 3 })
    assert equal ($nc_calls | length) (if $metric == 0 { 1 } else { 2 })
    assert equal ($sends.kind) ([...($curl_calls | each { 'curl' }) ...($nc_calls | each { 'nc' })])
    let tags = (['env:fixture' 'pool:synthetic-pool']
        | append (if $vdev { ['vdev:disk-one'] } else { [] }) | append 'vdev_state:DEGRADED')
    let title = $'ZFS Pool Health Change: synthetic-pool(if $vdev { " (vdev: disk-one)" } else { "" })'
    let text = (if $vdev { 'Pool: synthetic-pool\nVdev: disk-one\nNew State: DEGRADED\nPath: /synthetic/disk-one' } else { 'Pool: synthetic-pool\nNew State: DEGRADED' })
    for call in $curl_calls {
        let args = $call.args
        # Permit the HTTP-status sender draft to add curl options; validate payload and endpoint.
        assert ($args | any { $in == 'https://synthetic.invalid/api/v1/events' })
        assert ($args | any { $in == 'DD-API-KEY: synthetic-key' })
        assert ($args | any { $in == 'POST' })
        assert ($args | any { $in == 'Content-Type: application/json' })
        let payload = ($args | get (($args | enumerate | where item == '-d' | first | get index) + 1) | from json)
        assert equal $payload {title: $title, text: ($text | str replace -a '\n' (char newline)), priority: normal, tags: $tags, alert_type: warning, source_type_name: zfs, host: synthetic-host}
    }
    for call in $nc_calls {
        assert equal $call.args ['-u' '-w1' 'synthetic.invalid' '18125']
        assert equal $call.stdin $'zfs.pool.health:1|g|#($tags | str join ","),host:synthetic-host'
    }
    let failed = ($event != 0 or $metric != 0)
    assert equal $result.exit_code (if $failed { 1 } else { 0 })
    assert equal ($result.stderr | str contains '[ERROR] Pool health submission failed: synthetic-pool - DEGRADED') $failed
    assert equal ($result.stderr | str contains '[INFO] Pool health event processed: synthetic-pool - DEGRADED') (not $failed)
}

def main [] {
    let root = ($env.FILE_PWD | path join ../.. | path expand)
    let work = (^mktemp -d | str trim)
    try {
        mkdir ($work | path join bin)
        cp ($root | path join scripts/statechange-datadog.sh) $work
        cp ($root | path join scripts/zfs-datadog-lib.sh) $work
        'DD_API_KEY="synthetic-key"
DD_API_URL="https://synthetic.invalid"
DD_TAGS="env:fixture"
DOGSTATSD_HOST="synthetic.invalid"
DOGSTATSD_PORT="18125"
' | save ($work | path join config.sh)
        # Only known, harmless utilities are available to the shell and its library.
        for name in [dirname basename cat cut tr date] {
            ^ln -s ((which --all $name | where type == external | first).path) ($work | path join bin $name)
        }
        let shebang = $'#!($nu.current-exe) --no-config-file(char newline)'
        let stub = 'def --wrapped main [...args: string] {
    let kind = ($env.CURRENT_FILE | path basename)
    let data = (if $kind == "nc" { ^cat | complete | get stdout } else { "" })
    ({kind: $kind, args: $args, stdin: $data} | to json -r) + (char newline) | save --append $env.CALL_LOG
    if $kind == "curl" { print -n "202"; exit ($env.EVENT_RC | into int) }
    if $kind == "nc" { exit ($env.METRIC_RC | into int) }
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
        # Run the very same oracle against the pre-change zedlet from a fixed commit.
        let original = (^git -C $root show c9f4b0f1e89a6b9a73e9f07d9b2f2fbb2bec4495:scripts/statechange-datadog.sh | complete)
        assert equal $original.exit_code 0
        $original.stdout | save -f ($work | path join statechange-datadog.sh)
        check-case $work (which sh | first | get path) 0 0 true true
        let rejected = (try { check-case $work (which sh | first | get path) 7 9 true true; false } catch { true })
        assert $rejected 'Original zedlet unexpectedly passed failure oracle'
        print 'PASS original behavior rejected by failure oracle'
    } catch {|err|
        rm -rf $work
        error make {msg: $err.rendered}
    }
    rm -rf $work
}
