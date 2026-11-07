# SPDX-License-Identifier: MIT
# Synthetic transport tests: no real curl, nc, logger, sleep, pool or service.
def check [ok: bool, message: string] {
    if not $ok { error make {msg: $message} }
}
def main [] {
    let repo = ($env.PWD | path expand)
    let nu_exe = $nu.current-exe
    let root = (mktemp -d | str trim)
    try {
        let bin = ($root | path join bin)
        mkdir $bin
        for cmd in [cat cut dirname basename] {
            let source = (which $cmd | first | get path)
            ^ln -s $source ($bin | path join $cmd)
        }
        # Each executable is a Nu stub; argv[0] is encoded explicitly.
        for cmd in [curl nc sleep logger date] {
            let body = ('#!' + $nu_exe + "\n" + 'def --wrapped main [...args: string] {
    let cmd = "' + $cmd + '"
    let input = (if $cmd == "nc" { open --raw /dev/stdin } else { "" })
    {cmd: $cmd, args: $args, input: $input} | to json --raw | $in + "\n" | save --append $env.TRACE
    if $cmd == "curl" {
        let base = ["-s" "-m" "10" "-X" "POST" "https://synthetic.invalid/api/v1/events" "-H" "Content-Type: application/json" "-H" "DD-API-KEY: synthetic" "-d"]
        let ordinary = (($args | take 11) == $base) and (($args | length) == 12)
        let optional = (($args | take 5) == ["-s" "-o" "/dev/null" "-w" "%{http_code}"]) and (([...($args | take 1) ...($args | skip 5)] | take 11) == $base) and (($args | length) == 16)
        if not ($ordinary or $optional) { exit 91 }
        print -n "202"
        if ("event" in ($env.FAIL | split row ",")) { exit 1 }
    } else if $cmd == "nc" {
        if $args != ["-u" "-w1" "synthetic.invalid" "8125"] { exit 92 }
        let name = ($input | split row ":" | first | split row "." | last)
        if ($name in ($env.FAIL | split row ",")) { exit 1 }
    } else if $cmd == "date" { print "synthetic-time" }
}
')
            $body | save ($bin | path join $cmd)
            ^chmod +x ($bin | path join $cmd)
        }
        for kind in [scrub resilver] {
            cp ($repo | path join scripts $'($kind)_finish-datadog.sh') $root
        }
        cp ($repo | path join scripts zfs-datadog-lib.sh) $root
        mut cases = 0
        for shell in [sh dash bash] {
            let shell_path = (which $shell | first | get path)
            for kind in [scrub resilver] {
                for duration in [false true] {
                    let senders = (if $duration { [event errors duration in_progress] } else { [event errors in_progress] })
                    let count = (2 ** ($senders | length) | into int)
                    for mask in 0..<$count {
                        let failures = ($senders | enumerate | where {|x| (($mask // (2 ** $x.index | into int)) mod 2) == 1 } | get item)
                        for enabled in [true false] {
                            let trace = ($root | path join trace)
                            '' | save --force $trace
                            let end = (if $duration { '3760' } else { '0' })
                            let result = (^env -i $'PATH=($bin)' $'TRACE=($trace)' $'FAIL=($failures | str join ",")' DD_API_KEY=synthetic DD_API_URL=https://synthetic.invalid HOSTNAME=fixture DD_TAGS=env:test DOGSTATSD_HOST=synthetic.invalid DOGSTATSD_PORT=8125 $'MONITOR_SCRUB=($enabled)' $'MONITOR_RESILVER=($enabled)' ZEVENT_POOL=tank ZEVENT_VDEV_PATH=/synthetic/disk ZEVENT_VDEV_STATE=ONLINE $'ZEVENT_POOL_($kind | str uppercase)_ERRORS=2' $'ZEVENT_POOL_($kind | str uppercase)_START=100' $'ZEVENT_POOL_($kind | str uppercase)_END=($end)' $shell_path ($root | path join $'($kind)_finish-datadog.sh') | complete)
                            let context = $'($shell)/($kind)/duration=($duration)/mask=($mask)/enabled=($enabled)'
                            check ($result.exit_code == (if $enabled and ($failures | is-not-empty) { 1 } else { 0 })) $'exit: ($context): ($result.stderr)'
                            let records = (open --raw $trace | lines | each { from json })
                            let calls = ($records | where cmd in [curl nc])
                            if not $enabled {
                                check ($records | is-empty) $'disabled: ($context)'
                            } else {
                                let tags = 'env:test,pool:tank,vdev:disk,vdev_state:ONLINE,host:fixture'
                                mut expected = []
                                for sender in $senders {
                                    let retries = (if $sender in $failures { if $sender == event { 3 } else { 2 } } else { 1 })
                                    for attempt in 1..$retries { $expected = ($expected | append $sender) }
                                }
                                let actual = ($calls | each {|c| if $c.cmd == curl { 'event' } else { $c.input | split row ':' | first | split row '.' | last } })
                                check ($actual == $expected) $'order/retries: ($context)'
                                for call in $calls {
                                    if $call.cmd == curl {
                                        let index = ($call.args | enumerate | where item == '-d' | get index | first)
                                        let payload = ($call.args | get ($index + 1) | from json)
                                        let label = (if $kind == scrub { 'Scrub' } else { 'Resilver' })
                                        let timing = (if $duration { '1h 1m' } else { '0h 0m' })
                                        check ($payload == {title: $'ZFS ($label) Completed: tank', text: $"Pool: tank\nStatus: completed with errors\nErrors Found: 2\nDuration: ($timing)", priority: normal, tags: [env:test pool:tank vdev:disk vdev_state:ONLINE], alert_type: error, source_type_name: zfs, host: fixture}) $'event payload: ($context)'
                                    } else {
                                        let sender = ($call.input | split row ':' | first | split row '.' | last)
                                        let value = (match $sender { errors => '2', duration => '3660', in_progress => '0' })
                                        check ($call.input == $'zfs.($kind).($sender):($value)|g|#($tags)') $'metric payload: ($context)'
                                    }
                                }
                                let sleeps = ($records | where cmd == sleep | get args | flatten)
                                mut expected_sleeps = []
                                for sender in $senders {
                                    if $sender in $failures { $expected_sleeps = ($expected_sleeps | append (if $sender == event { ['1' '2'] } else { ['1'] })) }
                                }
                                check ($sleeps == $expected_sleeps) $'backoff: ($context)'
                                check ($result.stderr | str contains 'completion event processed: tank - 2 errors') $'completion log: ($context)'
                                check (($result.stderr | str contains 'completion sender failure: tank') == ($failures | is-not-empty)) $'failure log: ($context)'
                            }
                            $cases += 1
                        }
                    }
                }
            }
        }
        print $'PASS: ($cases) synthetic cases under sh/dash/bash; no backend delivery assertion'
    } catch {|err|
        rm -rf $root
        error make {msg: $err.msg}
    }
    rm -rf $root
}
