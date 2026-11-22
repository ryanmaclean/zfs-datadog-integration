# SPDX-License-Identifier: MIT
# Synthetic transport tests: no real nc, logger, pool or service, and no curl at all.
use datagram.nu *

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
        for cmd in [cat cut dirname basename wc] {
            let source = (which $cmd | first | get path)
            ^ln -s $source ($bin | path join $cmd)
        }
        # Each executable is a Nu stub; argv[0] is encoded explicitly. Events and
        # metrics are both loopback datagrams on nc; the library never retries.
        for cmd in [curl nc sleep logger date] {
            let body = ('#!' + $nu_exe + "\n" + 'def --wrapped main [...args: string] {
    let cmd = "' + $cmd + '"
    let input = (if $cmd == "nc" { open --raw /dev/stdin } else { "" })
    {cmd: $cmd, args: $args, input: $input} | to json --raw | $in + "\n" | save --append $env.TRACE
    if $cmd == "nc" {
        if $args != ["-u" "-w1" "127.0.0.1" "8125"] { exit 92 }
        let name = (if ($input | str starts-with "_e{") { "event" } else { $input | split row ":" | first | split row "." | last })
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
                            let result = (^env -i $'PATH=($bin)' $'TRACE=($trace)' $'FAIL=($failures | str join ",")' HOSTNAME=fixture DD_TAGS=env:test DOGSTATSD_HOST=127.0.0.1 DOGSTATSD_PORT=8125 $'MONITOR_SCRUB=($enabled)' $'MONITOR_RESILVER=($enabled)' ZEVENT_POOL=tank ZEVENT_VDEV_PATH=/synthetic/disk ZEVENT_VDEV_STATE=ONLINE $'ZEVENT_POOL_($kind | str upcase)_ERRORS=2' $'ZEVENT_POOL_($kind | str upcase)_START=100' $'ZEVENT_POOL_($kind | str upcase)_END=($end)' $shell_path ($root | path join $'($kind)_finish-datadog.sh') | complete)
                            let context = $'($shell)/($kind)/duration=($duration)/mask=($mask)/enabled=($enabled)'
                            check ($result.exit_code == (if $enabled and ($failures | is-not-empty) { 1 } else { 0 })) $'exit: ($context): ($result.stderr)'
                            let records = (open --raw $trace | lines | each { from json })
                            let calls = ($records | where cmd == nc)
                            if not $enabled {
                                check ($records | is-empty) $'disabled: ($context)'
                            } else {
                                let tags = 'env:test,pool:tank,vdev:disk,vdev_state:ONLINE'
                                # Exactly one datagram per sender, in order; no curl, no sleep, no retry.
                                check ($records | where cmd in [curl sleep] | is-empty) $'no curl or sleep: ($context)'
                                let actual = ($calls | each {|c| if (datagram is-event $c.input) { 'event' } else { $c.input | split row ':' | first | split row '.' | last } })
                                check ($actual == $senders) $'order/attempts: ($context)'
                                for call in $calls {
                                    if (datagram is-event $call.input) {
                                        let payload = (datagram event $call.input)
                                        let label = (if $kind == scrub { 'Scrub' } else { 'Resilver' })
                                        let timing = (if $duration { '1h 1m' } else { 'unknown' })
                                        check ($payload == {title: $'ZFS ($label) Completed: tank', text: $'Pool: tank\nEvent ID: unknown\nStatus: completed with errors\nErrors Found: 2\nDuration: ($timing)', priority: normal, alert_type: error, source: zfs, tags: [env:test pool:tank vdev:disk vdev_state:ONLINE]}) $'event payload: ($context)'
                                    } else {
                                        let sender = ($call.input | split row ':' | first | split row '.' | last)
                                        let value = (match $sender { errors => '2', duration => '3660', in_progress => '0' })
                                        let metric_tags = (if $sender == 'in_progress' { 'env:test,pool:tank' } else { $tags })
                                        check ($call.input == $'zfs.($kind).($sender):($value)|g|#($metric_tags)') $'metric payload: ($context)'
                                    }
                                }
                                check ($result.stderr | str contains 'completion event processed: tank - 2 errors') $'completion log: ($context)'
                                check (($result.stderr | str contains 'completion sender failure: tank') == ($failures | is-not-empty)) $'failure log: ($context)'
                                check (($result.stderr | str contains 'Local Agent event handoff failed') == ('event' in $failures)) $'event handoff log: ($context)'
                                let metric_failures = ($failures | where {|f| $f != 'event' } | length)
                                check (($result.stderr | lines | where {|l| $l | str contains 'Local Agent metric handoff failed' } | length) == $metric_failures) $'metric handoff log: ($context)'
                            }
                            $cases += 1
                        }
                    }
                }
            }
        }
        print $'PASS: ($cases) synthetic cases under sh/dash/bash; no backend delivery assertion'
    } catch {|err|
        rm -r $root
        error make {msg: $err.msg}
    }
    rm -r $root
}
