# SPDX-License-Identifier: MIT
# No network: only allowlisted utilities and synthetic Nu transports enter PATH.
use std/assert
use datagram.nu *

def main [] {
    let repo = ($env.CURRENT_FILE | path dirname | path dirname | path dirname)
    let nu_bin = $nu.current-exe
    let shells = ([sh dash bash] | each {|name| which $name | get path | first })
    let envcmd = (which env | get path | first)
    let chmod = (which chmod | get path | first)
    let root = (mktemp -d -t io-senders.XXXXXXXX)
    try {
        let bin = ($root | path join bin)
        mkdir $bin
        cp ($repo | path join scripts/io-error.sh) $root
        cp ($repo | path join scripts/zfs-datadog-lib.sh) $root
        for name in [dirname basename cat cut date wc] {
            let source = ([/usr/bin /bin] | each { path join $name } | where { path exists } | first)
            ln -s $source ($bin | path join $name)
        }
        # No curl: events and metrics are both loopback datagrams handed to nc.
        let stub = '
def --wrapped main [...args: string] {
    let name = ($env.CURRENT_FILE | path basename)
    let input = if $name == "nc" { open --raw /dev/stdin } else { "" }
    {name: $name, args: $args, input: $input} | to json -r | $in + "\n" | save --append $env.TRACE
    if $name == "nc" {
        let key = (if ($input | str starts-with "_e{") { "event" } else { $input | split row ":" | first })
        exit (if $key in ($env.FAIL_SENDERS | split row ",") { 1 } else { 0 })
    }
}
'
        for name in [curl nc sleep logger] {
            let target = ($bin | path join $name)
            ($"#!($nu_bin) --no-config-file\n" + $stub) | save $target
            ^$chmod +x $target
        }
        mut cases = 0
        for shell in $shells {
            for read in [0 7] {
                for write in [0 9] {
                    let metrics = ([{name: zfs.io.error, value: 1}] | append (if $read > 0 { [{name: zfs.io.read_errors, value: $read}] } else { [] }) | append (if $write > 0 { [{name: zfs.io.write_errors, value: $write}] } else { [] }))
                    let n = ($metrics | length)
                    for mask in 0..<(2 ** ($n + 1)) {
                        let event_fail = ($mask mod 2)
                        let failed = ($metrics | enumerate | where {|m| (($mask // (2 ** ($m.index + 1))) mod 2) == 1 } | get item.name)
                        let fail_senders = (if $event_fail == 1 { ['event'] | append $failed } else { $failed })
                        for enabled in [true false] {
                            let trace = ($root | path join trace)
                            '' | save -f $trace
                            let result = (^$envcmd -i $'PATH=($bin)' $'HOME=($root)' LC_ALL=C HOSTNAME=fixture DOGSTATSD_HOST=127.0.0.1 DOGSTATSD_PORT=18125 DD_TAGS=env:test ZEVENT_POOL=tank ZEVENT_VDEV_PATH=/synthetic/disk ZEVENT_VDEV_STATE=FAULTED ...(if $read > 0 { [$'ZEVENT_VDEV_READ_ERRORS=($read)'] } else { [] }) ...(if $write > 0 { [$'ZEVENT_VDEV_WRITE_ERRORS=($write)'] } else { [] }) $'MONITOR_IO_ERRORS=($enabled)' $'TRACE=($trace)' $'FAIL_SENDERS=($fail_senders | str join ,)' $shell ($root | path join io-error.sh) | complete)
                            let calls = (open --raw $trace | lines | each { from json })
                            let context = $'($shell) read=($read) write=($write) mask=($mask) enabled=($enabled)'
                            if not $enabled {
                                assert equal $result.exit_code 0
                                assert equal $result.stderr ''
                                assert equal $calls []
                            } else {
                                let bad = ($event_fail == 1 or ($failed | is-not-empty))
                                assert equal $result.exit_code (if $bad { 1 } else { 0 }) $'($context): exit ($result.stderr)'
                                assert ($result.stderr | str contains $'I/O error detected: tank - disk - R:($read) W:($write)') $context
                                assert equal ($result.stderr | str contains 'I/O error reporting failed:') $bad
                                assert equal ($result.stderr | str contains 'Local Agent event handoff failed') ($event_fail == 1) $context
                                assert equal ($result.stderr | lines | where { $in | str contains 'Local Agent metric handoff failed' } | length) ($failed | length) $context
                                let tags = 'env:test,pool:tank,vdev:disk,vdev_state:FAILED_PLACEHOLDER' | str replace FAILED_PLACEHOLDER FAULTED
                                let want_event = {title: 'ZFS I/O Error: tank', text: $'Pool: tank\nVdev: disk\nRead Errors: ($read)\nWrite Errors: ($write)\nPath: /synthetic/disk\nVdev State: FAULTED', priority: normal, alert_type: error, source: zfs, tags: ($tags | split row ,)}
                                # One datagram per send, in order: event then each metric. No retries, no sleeps, no curl.
                                assert equal ($calls | where name in [curl sleep] | length) 0 $context
                                let transport = ($calls | where name == nc)
                                assert equal ($transport | length) (1 + $n) $context
                                for call in $transport {
                                    assert equal $call.args [-u -w1 127.0.0.1 '18125'] $context
                                }
                                assert equal (datagram event ($transport | first | get input)) $want_event $context
                                assert equal ($transport | skip 1 | get input) ($metrics | each {|m| $'($m.name):($m.value)|c|#($tags)' }) $context
                                let logs = ($calls | where name == logger | get args | each { last })
                                assert equal ($logs | where { $in | str contains 'I/O error reporting failed:' } | length) (if $bad { 1 } else { 0 }) $context
                                assert ($logs | last | str contains (if $bad { 'I/O error reporting failed:' } else { 'I/O error detected:' })) $context
                            }
                            $cases += 1
                        }
                    }
                }
            }
        }
        print $'PASS: ($cases) isolated cases across sh/dash/bash; datagrams, ordering, single-attempt sends, status and disabled behavior'
    } catch {|err|
        rm -r $root
        error make $err
    }
    rm -r $root
}
