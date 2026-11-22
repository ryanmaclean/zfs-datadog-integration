#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Run with nu --no-config-file. Only synthetic transports are reachable.
use datagram.nu *

def assert [condition: bool, message: string] {
    if not $condition { error make {msg: $message} }
}

def "assert equal" [actual: any, expected: any, context: string] {
    assert ($actual == $expected) $'($context): expected ($expected | to nuon), got ($actual | to nuon)'
}

def main [] {
    let repo = ($env.CURRENT_FILE | path dirname | path dirname | path dirname)
    let tmp = (mktemp -d)
    try {
        let bin = ($tmp | path join bin)
        mkdir $bin
        for name in [dirname basename cat cut wc] {
            ^/bin/ln -s $'/usr/bin/($name)' ($bin | path join $name)
        }
        cp ($repo | path join scripts/checksum-error.sh) $tmp
        cp ($repo | path join scripts/zfs-datadog-lib.sh) $tmp
        # No repository config is copied or sourced. There is no curl: the
        # only transport is the loopback datagram handed to nc.
        let stub = '
def --wrapped main [...args: string] {
    let kind = ($env.CURRENT_FILE | path basename)
    let input = if $kind == "nc" { open --raw /dev/stdin } else { "" }
    {kind: $kind, args: $args, input: $input} | to json --raw | $in + "\n" | save --append $env.TRACE
    if $kind == "nc" { exit (if ($input | str starts-with "_e{") { $env.EVENT_RC | into int } else { $env.METRIC_RC | into int }) }
    if $kind == "date" { print "2000-01-01 00:00:00" }
}
'
        for name in [curl nc sleep logger date] {
            let file = ($bin | path join $name)
            ($'#!($nu.current-exe) --no-config-file' + "\n" + $stub) | save $file
            ^/bin/chmod +x $file
        }
        mut count = 0
        for shell in [/bin/sh /bin/dash /bin/bash] {
            for state in ["" DEGRADED] {
                for event in [0 7] {
                    for metric in [0 9] {
                        for enabled in [true false] {
                            let trace = ($tmp | path join trace)
                            '' | save --force $trace
                            let result = (^/usr/bin/env -i $'PATH=($bin)' 'HOSTNAME=testhost' 'DD_TAGS=env:test' 'DOGSTATSD_HOST=127.0.0.1' 'DOGSTATSD_PORT=18125' 'ZEVENT_POOL=tank' 'ZEVENT_VDEV_PATH=/synthetic/disk0' 'ZEVENT_VDEV_CKSUM_ERRORS=17' ...(if $state == '' { [] } else { [$'ZEVENT_VDEV_STATE=($state)'] }) $'MONITOR_CHECKSUM_ERRORS=($enabled)' $'EVENT_RC=($event)' $'METRIC_RC=($metric)' $'TRACE=($trace)' $shell ($tmp | path join checksum-error.sh) | complete)
                            assert equal $result.stdout '' "zedlet stdout"
                            assert (not ($result.stderr | str contains 'Error: nu::')) "stub execution must succeed"
                            let calls = (open --raw $trace | lines | each { from json })
                            let context = $'($shell) state=($state) event=($event) metric=($metric) enabled=($enabled)'
                            if not $enabled {
                                assert equal $result.exit_code 0 $context
                                assert equal $calls [] $context
                                assert equal $result.stderr '' $context
                            } else {
                                let failed = ($event != 0 or $metric != 0)
                                assert equal $result.exit_code (if $failed { 1 } else { 0 }) $"($context) ($result.stderr)"
                                assert ($result.stderr | str contains 'Checksum error detected: tank - disk0 - 17 errors') $context
                                assert equal ($result.stderr | str contains 'Checksum error reporting failed: tank - disk0') $failed $context
                                assert equal ($result.stderr | str contains 'Local Agent event handoff failed') ($event != 0) $context
                                assert equal ($result.stderr | str contains 'Local Agent metric handoff failed') ($metric != 0) $context
                                # Exactly one datagram per send, event first, no curl and no sleep.
                                assert equal ($calls | where kind in [curl sleep] | length) 0 $context
                                let transports = ($calls | where kind == nc)
                                assert equal ($transports | each {|c| datagram is-event $c.input }) [true false] $context
                                let tags = ([env:test pool:tank vdev:disk0] | append (if $state == '' { [] } else { [$'vdev_state:($state)'] }))
                                let text = ('Pool: tank\nVdev: disk0\nChecksum Errors: 17\nPath: /synthetic/disk0') + (if $state == '' { '' } else { $'\nVdev State: ($state)' })
                                for call in $transports {
                                    assert equal $call.args [-u -w1 127.0.0.1 '18125'] $context
                                }
                                assert equal (datagram event ($transports | first | get input)) {title: 'ZFS Checksum Error: tank', text: $text, priority: normal, alert_type: error, source: zfs, tags: $tags} $context
                                assert equal ($transports | last | get input) $'zfs.checksum.errors:17|c|#($tags | str join ",")' $context
                            }
                            $count += 1
                        }
                    }
                }
            }
        }
        print $'PASS: ($count) isolated cases across sh/dash/bash'
    } catch {|err|
        rm -r $tmp
        error make {msg: $err.msg}
    }
    rm -r $tmp
}
