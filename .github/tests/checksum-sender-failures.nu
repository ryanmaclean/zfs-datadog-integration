#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Run with nu --no-config-file. Only synthetic transports are reachable.
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
        for name in [dirname basename cat cut] {
            ^/bin/ln -s $'/usr/bin/($name)' ($bin | path join $name)
        }
        cp ($repo | path join scripts/checksum-error.sh) $tmp
        cp ($repo | path join scripts/zfs-datadog-lib.sh) $tmp
        # No repository config is copied or sourced.
        let stub = '
def --wrapped main [...args: string] {
    let kind = ($env.CURRENT_FILE | path basename)
    let input = if $kind == "nc" { open --raw /dev/stdin } else { "" }
    {kind: $kind, args: $args, input: $input} | to json --raw | $in + "\n" | save --append $env.TRACE
    if $kind == "curl" { print -n "202"; exit ($env.EVENT_RC | into int) }
    if $kind == "nc" { exit ($env.METRIC_RC | into int) }
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
                            let result = (^/usr/bin/env -i $'PATH=($bin)' 'HOSTNAME=testhost' 'DD_API_KEY=synthetic' 'DD_API_URL=https://example.invalid' 'DD_TAGS=env:test' 'DOGSTATSD_HOST=synthetic.invalid' 'DOGSTATSD_PORT=18125' 'ZEVENT_POOL=tank' 'ZEVENT_VDEV_PATH=/synthetic/disk0' 'ZEVENT_VDEV_CKSUM_ERRORS=17' ...(if $state == '' { [] } else { [$'ZEVENT_VDEV_STATE=($state)'] }) $'MONITOR_CHECKSUM_ERRORS=($enabled)' $'EVENT_RC=($event)' $'METRIC_RC=($metric)' $'TRACE=($trace)' $shell ($tmp | path join checksum-error.sh) | complete)
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
                                assert equal $result.exit_code (if $failed { 1 } else { 0 }) $context
                                assert ($result.stderr | str contains 'Checksum error detected: tank - disk0 - 17 errors') $context
                                assert equal ($result.stderr | str contains 'Checksum error reporting failed: tank - disk0') $failed $context
                                let transports = ($calls | where kind in [curl nc sleep])
                                let expected_order = ([curl] | append (if $event == 0 { [] } else { [sleep curl sleep curl] }) | append [nc] | append (if $metric == 0 { [] } else { [sleep nc] }))
                                assert equal ($transports | get kind) $expected_order $context
                                assert equal ($calls | where kind == sleep | get args) ((if $event == 0 { [] } else { [['1'] ['2']] }) | append (if $metric == 0 { [] } else { [['1']] })) $context
                                let tags = ([env:test pool:tank vdev:disk0] | append (if $state == '' { [] } else { [$'vdev_state:($state)'] }))
                                let text = ('Pool: tank\nVdev: disk0\nChecksum Errors: 17\nPath: /synthetic/disk0' | str replace --all '\n' (char newline)) + (if $state == '' { '' } else { $'\nVdev State: ($state)' | str replace --all '\n' (char newline) })
                                for call in ($calls | where kind == curl) {
                                    # #40 may add exactly these HTTP status output options.
                                    mut args = $call.args
                                    for pair in [[-o /dev/null] [-w '%{http_code}']] {
                                        let pos = ($args | enumerate | where item == $pair.0 | get index)
                                        if ($pos | is-not-empty) {
                                            assert equal ($pos | length) 1 $context
                                            let i = $pos.0
                                            assert equal ($args | skip $i | take 2) $pair $context
                                            $args = ($args | enumerate | where {|x| $x.index < $i or $x.index > ($i + 1) } | get item)
                                        }
                                    }
                                    assert equal ($args | take 11) [-s -m '10' -X POST https://example.invalid/api/v1/events -H 'Content-Type: application/json' -H 'DD-API-KEY: synthetic' -d] $context
                                    assert equal ($args | length) 12 $context
                                    assert equal ($args | last | from json) {title: 'ZFS Checksum Error: tank', text: $text, priority: normal, tags: $tags, alert_type: error, source_type_name: zfs, host: testhost} $context
                                }
                                for call in ($calls | where kind == nc) {
                                    assert equal $call.args [-u -w1 synthetic.invalid '18125'] $context
                                    assert equal $call.input $'zfs.checksum.errors:17|c|#($tags | str join ","),host:testhost' $context
                                }
                            }
                            $count += 1
                        }
                    }
                }
            }
        }
        print $'PASS: ($count) isolated cases across sh/dash/bash'
    } catch {|err|
        rm -rf $tmp
        error make {msg: $err.msg}
    }
    rm -rf $tmp
}
