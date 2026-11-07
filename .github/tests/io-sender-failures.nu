# SPDX-License-Identifier: MIT
# No network: only allowlisted utilities and synthetic Nu transports enter PATH.
use std/assert

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
        for name in [dirname basename cat cut date] {
            let source = ([/usr/bin /bin] | each { path join $name } | where { path exists } | first)
            ln -s $source ($bin | path join $name)
        }
        let stub = '
def --wrapped main [...args: string] {
    let name = ($env.CURRENT_FILE | path basename)
    let input = if $name == "nc" { open --raw /dev/stdin } else { "" }
    {name: $name, args: $args, input: $input} | to json -r | $in + "\n" | save --append $env.TRACE
    if $name == "curl" { print -n "202"; exit ($env.EVENT_FAIL | into int) }
    if $name == "nc" {
        let metric = ($input | split row ":" | first)
        exit (if $metric in ($env.FAIL_METRICS | split row ",") { 1 } else { 0 })
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
                        for enabled in [true false] {
                            let trace = ($root | path join trace)
                            '' | save -f $trace
                            let result = (^$envcmd -i $'PATH=($bin)' $'HOME=($root)' LC_ALL=C HOSTNAME=fixture DD_API_KEY=synthetic DD_API_URL=https://invalid.example DOGSTATSD_HOST=invalid.example DOGSTATSD_PORT=18125 DD_TAGS=env:test ZEVENT_POOL=tank ZEVENT_VDEV_PATH=/synthetic/disk ZEVENT_VDEV_STATE=FAULTED ...(if $read > 0 { [$'ZEVENT_VDEV_READ_ERRORS=($read)'] } else { [] }) ...(if $write > 0 { [$'ZEVENT_VDEV_WRITE_ERRORS=($write)'] } else { [] }) $'MONITOR_IO_ERRORS=($enabled)' $'TRACE=($trace)' $'EVENT_FAIL=($event_fail)' $'FAIL_METRICS=($failed | str join ,)' $shell ($root | path join io-error.sh) | complete)
                            let calls = (open --raw $trace | lines | each { from json })
                            if not $enabled {
                                assert equal $result.exit_code 0
                                assert equal $result.stderr ''
                                assert equal $calls []
                            } else {
                                let bad = ($event_fail == 1 or ($failed | is-not-empty))
                                assert equal $result.exit_code (if $bad { 1 } else { 0 })
                                assert ($result.stderr | str contains $'I/O error detected: tank - disk - R:($read) W:($write)')
                                assert equal ($result.stderr | str contains 'I/O error reporting failed:') $bad
                                mut expected = []
                                let tags = 'env:test,pool:tank,vdev:disk,vdev_state:FAULTED'
                                let payload = {title: 'ZFS I/O Error: tank', text: $"Pool: tank\nVdev: disk\nRead Errors: ($read)\nWrite Errors: ($write)\nPath: /synthetic/disk\nVdev State: FAULTED", priority: normal, tags: ($tags | split row ,), alert_type: error, source_type_name: zfs, host: fixture}
                                for attempt in 1..(if $event_fail == 1 { 3 } else { 1 }) {
                                    $expected = ($expected | append {name: curl})
                                    if $event_fail == 1 and $attempt < 3 { $expected = ($expected | append {name: sleep, args: [($attempt | into string)]}) }
                                }
                                for m in $metrics {
                                    for attempt in 1..(if $m.name in $failed { 2 } else { 1 }) {
                                        $expected = ($expected | append {name: nc, args: [-u -w1 invalid.example '18125'], input: $'($m.name):($m.value)|c|#($tags),host:fixture'})
                                        if $m.name in $failed and $attempt == 1 { $expected = ($expected | append {name: sleep, args: ['1']}) }
                                    }
                                }
                                let transport = ($calls | where name != logger)
                                assert equal ($transport | get name) ($expected | get name)
                                for pair in ($transport | zip $expected) {
                                    let actual = $pair.0
                                    let want = $pair.1
                                    if $actual.name == curl {
                                        let args = (if ($actual.args | first 5) == [-s -o /dev/null -w '%{http_code}'] { [-s ...($actual.args | skip 5)] } else { $actual.args })
                                        let index = ($args | enumerate | where item == '-d' | get index | first)
                                        assert equal ($args | get ($index + 1) | from json) $payload
                                        assert equal ($args | first ($index + 1)) [-s -m '10' -X POST https://invalid.example/api/v1/events -H 'Content-Type: application/json' -H 'DD-API-KEY: synthetic' -d]
                                        assert equal ($args | length) ($index + 2)
                                    } else {
                                        assert equal $actual.args $want.args
                                        if $actual.name == nc { assert equal $actual.input $want.input }
                                    }
                                }
                                let logs = ($calls | where name == logger | get args | each { last })
                                assert equal ($logs | where { $in | str contains 'I/O error reporting failed:' } | length) (if $bad { 1 } else { 0 })
                                assert ($logs | last | str contains (if $bad { 'I/O error reporting failed:' } else { 'I/O error detected:' }))
                            }
                            $cases += 1
                        }
                    }
                }
            }
        }
        print $'PASS: ($cases) isolated cases across sh/dash/bash; payloads, ordering, retries, status and disabled behavior'
    } catch {|err|
        rm -rf $root
        error make $err
    }
    rm -rf $root
}
