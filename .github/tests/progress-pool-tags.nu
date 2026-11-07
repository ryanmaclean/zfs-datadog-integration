#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic only: no configuration, inherited environment, network or ZFS tools.
def check [ok: bool, message: string] { if not $ok { error make {msg: $message} } }
def main [] {
    let repo = ($env.FILE_PWD | path join ../.. | path expand)
    let nu_exe = $nu.current-exe
    let root = (mktemp -d | str trim)
    try {
        let bin = ($root | path join bin)
        mkdir $bin
        for tool in [dirname cat cut tr basename date] {
            ^ln -s ($"/usr/bin/($tool)") ($bin | path join $tool)
        }
        for scan in [scrub resilver] {
            for phase in [start finish] {
                cp ($repo | path join $"scripts/($scan)_($phase)-datadog.sh") $root
            }
        }
        cp ($repo | path join scripts/zfs-datadog-lib.sh) $root
        # Executable Nushell fixtures only. curl accepts both legacy arguments and
        # draft #40 strict HTTP options (-o /dev/null and -w HTTP status).
        ($'#!($nu_exe) --stdin' + '
 def main --wrapped [...args: string] {
 if (("-o" in $args) != ("-w" in $args)) { error make {msg: "strict HTTP options must be paired"} }
 if "-o" in $args {
   let oi = ($args | enumerate | where item == "-o" | get 0.index)
   let wi = ($args | enumerate | where item == "-w" | get 0.index)
   if (($args | get ($oi + 1)) != "/dev/null") or (($args | get ($wi + 1)) != "%{http_code}") { error make {msg: "unexpected strict HTTP options"} }
 }
 let i = ($args | enumerate | where item == "-d" | get 0.index)
 ($args | get ($i + 1) | from json | to json -r) + "\n" | save --append $env.EVENTS
 print -n "202"
 }
') | save ($bin | path join curl)
        ($'#!($nu_exe) --stdin' + '
 def main --wrapped [...args: string] { ($in | str trim) + "\n" | save --append $env.METRICS }
') | save ($bin | path join nc)
        ($'#!($nu_exe)' + '
 def main --wrapped [...args: string] { }
') | save ($bin | path join logger)
        ^chmod +x ($bin | path join curl) ($bin | path join nc) ($bin | path join logger)
        mut runs = 0
        for shell in [sh dash bash] {
            for scan in [scrub resilver] {
                for pool in [tank backup ""] {
                    for static in ['env:test,service:zfs' 'env:test,vdev:user,vdev_state:static,pool:user'] {
                      for finish_vdev in ['/dev/finish-disk' ''] {
                        mut identities = []
                        for phase in [start finish] {
                            let metrics = ($root | path join metrics)
                            let events = ($root | path join events)
                            '' | save -f $metrics
                            '' | save -f $events
                            let vdev = (if $phase == start { '/dev/start-disk' } else { $finish_vdev })
                            let state = (if $phase == start { 'DEGRADED' } else { 'ONLINE' })
                            let result = (^env -i $'PATH=($bin)' $'HOSTNAME=synthetic-host' 'DD_API_KEY=synthetic-key' 'MONITOR_SCRUB=true' 'MONITOR_RESILVER=true' $'DD_TAGS=($static)' $'ZEVENT_POOL=($pool)' $'ZEVENT_VDEV_PATH=($vdev)' $'ZEVENT_VDEV_STATE=($state)' 'ZEVENT_POOL_SCRUB_START=100' 'ZEVENT_POOL_SCRUB_END=160' 'ZEVENT_POOL_RESILVER_START=100' 'ZEVENT_POOL_RESILVER_END=160' $'METRICS=($metrics)' $'EVENTS=($events)' $'/usr/bin/($shell)' ($root | path join $'($scan)_($phase)-datadog.sh') | complete)
                            check ($result.exit_code == 0) $'($shell) ($scan) ($phase) failed: ($result.stderr)'
                            let pooltag = (if $pool == '' { 'unknown' } else { $pool })
                            let stable = $'($static),pool:($pooltag)'
                            let eventtags = $'($stable)(if $vdev == "" { "" } else { $",vdev:($vdev | path basename)" }),vdev_state:($state)'
                            let value = (if $phase == start { 1 } else { 0 })
                            let progress = $'zfs.($scan).in_progress:($value)|g|#($stable),host:synthetic-host'
                            let others = (if $phase == start { [$'zfs.($scan).start:1|c|#($eventtags),host:synthetic-host'] } else { [$'zfs.($scan).errors:0|g|#($eventtags),host:synthetic-host' $'zfs.($scan).duration:60|g|#($eventtags),host:synthetic-host'] })
                            let actual = (open --raw $metrics | lines)
                            check ($actual == ($others | append $progress)) $'metric values/tags/order: ($actual) stderr=($result.stderr)'
                            let event = (open --raw $events | from json)
                            check ($event.tags == ($eventtags | split row ',')) 'event tags changed'
                            check ($event.host == 'synthetic-host') 'event host changed'
                            $identities = ($identities | append ($actual | last | split row '|#' | last))
                            $runs = $runs + 1
                        }
                        check ($identities.0 == $identities.1) 'start/finish series differ'
                      }
                    }
                }
            }
        }
        print $'PASS: ($runs) isolated synthetic zedlet runs across sh/dash/bash'
    } catch {|err| rm -rf $root; error make {msg: $err.msg} }
    rm -rf $root
}
