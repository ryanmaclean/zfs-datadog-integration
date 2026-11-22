#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic only: no configuration, inherited environment, network or ZFS tools.
# Events and metrics are loopback DogStatsD datagrams recorded by a stub nc.
use datagram.nu *

def check [ok: bool, message: string] { if not $ok { error make {msg: $message} } }
def main [] {
    let repo = ($env.FILE_PWD | path join ../.. | path expand)
    let nu_exe = $nu.current-exe
    let root = (mktemp -d | str trim)
    try {
        let bin = ($root | path join bin)
        mkdir $bin
        for tool in [dirname cat cut tr basename date wc mktemp rm] {
            ^ln -s (which --all $tool | where type == external | first | get path) ($bin | path join $tool)
        }
        for scan in [scrub resilver] {
            for phase in [start finish] {
                cp ($repo | path join $"scripts/($scan)_($phase)-datadog.sh") $root
            }
        }
        cp ($repo | path join scripts/zfs-datadog-lib.sh) $root
        # Executable Nushell fixtures only. nc appends each datagram to one
        # file; events and metrics are told apart by the _e{ prefix.
        ($'#!($nu_exe) --stdin' + '
 def main --wrapped [...args: string] {
   if $args != ["-u" "-w0" "127.0.0.1" "18125"] { error make {msg: $"unexpected nc args ($args)"} }
   let packet = ($in | str trim)
   let file = (if ($packet | str starts-with "_e{") { $env.EVENTS } else { $env.METRICS })
   $packet + "\n" | save --append $file
 }
') | save ($bin | path join nc)
        ($'#!($nu_exe)' + '
 def main --wrapped [...args: string] { }
') | save ($bin | path join logger)
        ^chmod +x ($bin | path join nc) ($bin | path join logger)
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
                            let result = (^env -i $'PATH=($bin)' $'TMPDIR=($bin)' $'HOSTNAME=synthetic-host' 'DOGSTATSD_HOST=127.0.0.1' 'DOGSTATSD_PORT=18125' 'MONITOR_SCRUB=true' 'MONITOR_RESILVER=true' $'DD_TAGS=($static)' $'ZEVENT_POOL=($pool)' $'ZEVENT_VDEV_PATH=($vdev)' $'ZEVENT_VDEV_STATE=($state)' 'ZEVENT_POOL_SCRUB_START=100' 'ZEVENT_POOL_SCRUB_END=160' 'ZEVENT_POOL_RESILVER_START=100' 'ZEVENT_POOL_RESILVER_END=160' $'METRICS=($metrics)' $'EVENTS=($events)' $'/usr/bin/($shell)' ($root | path join $'($scan)_($phase)-datadog.sh') | complete)
                            check ($result.exit_code == 0) $'($shell) ($scan) ($phase) failed: ($result.stderr)'
                            let pooltag = (if $pool == '' { 'unknown' } else { $pool })
                            let stable = $'($static),pool:($pooltag)'
                            let eventtags = $'($stable)(if $vdev == "" { "" } else { $",vdev:($vdev | path basename)" }),vdev_state:($state)'
                            let value = (if $phase == start { 1 } else { 0 })
                            let progress = $'zfs.($scan).in_progress:($value)|g|#($stable)'
                            let others = (if $phase == start { [$'zfs.($scan).start:1|c|#($eventtags)'] } else { [$'zfs.($scan).duration:60|g|#($eventtags)'] })
                            let actual = (open --raw $metrics | lines)
                            check ($actual == ($others | append $progress)) $'metric values/tags/order: ($actual) stderr=($result.stderr)'
                            let packets = (open --raw $events | lines)
                            check (($packets | length) == 1) 'exactly one event datagram'
                            let event = (datagram event $packets.0)
                            check ($event.tags == ($eventtags | split row ',')) $'event tags changed: ($event.tags)'
                            check ($event.source == 'zfs') 'event source changed'
                            if $phase == finish {
                                check ($event.alert_type == 'info') 'missing error count must not imply success'
                                check ($event.text | str contains 'Errors Found: unknown') 'missing error count must remain unknown'
                            }
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
