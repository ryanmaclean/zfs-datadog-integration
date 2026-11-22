#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic integration tests: only recording nc/logger stubs are in PATH.
# Events and metrics both leave as DogStatsD datagrams to the loopback Agent;
# the library must never retry or sleep.
use datagram.nu *

def check [ok: bool, message: string] {
    if not $ok { error make {msg: $message} }
}

def run-tests [root: string, fixture: string, nu_exe: string] {
    let bin = ($fixture | path join bin)
    mkdir $bin
    for tool in [dirname basename date cat wc mktemp rm] {
        let target = (which --all $tool | where type == external | first | get path)
        ^ln -s $target ($bin | path join $tool)
    }
    let stub = ('#!' + $nu_exe + " --no-config-file\n" + 'def --wrapped main [...args: string] {
    let name = ($env.CURRENT_FILE | path basename)
    let file = ($env.CAPTURE | path join $name)
    let input = (if $name == "nc" { open --raw /dev/stdin } else { "" })
    ({args: $args, input: $input} | to json -r) + (char newline) | save --append $file
    if $name == "nc" and $env.NC_RC != "0" { exit ($env.NC_RC | into int) }
}
')
    for tool in [nc logger sleep curl] {
        $stub | save ($bin | path join $tool)
        ^chmod +x ($bin | path join $tool)
    }
    cp ($root | path join scripts zfs-datadog-lib.sh) $fixture
    let cases = [
        {name: config_sync, title: 'ZFS Config Sync: tank', text: 'Pool configuration synchronized for tank on host synthetic-host', alert: info, priority: low}
        {name: pool_destroy, title: 'ZFS Pool Destroyed: tank', text: 'Pool tank has been destroyed on host synthetic-host', alert: warning, priority: normal}
        {name: vdev_attach, title: 'ZFS Device Attached: tank', text: 'A new device has been attached to pool tank on host synthetic-host. Resilvering will begin automatically.', alert: info, priority: normal}
        {name: vdev_remove, title: 'ZFS Device Removed: tank', text: 'A device has been removed from pool tank on host synthetic-host', alert: warning, priority: normal}
    ]
    mut count = 0
    for shell in [sh dash bash] {
        let interpreter = (which $shell | first | get path)
        for case in $cases {
            let handler = ($case.name + '-datadog.sh')
            cp ($root | path join scripts $handler) $fixture
            for scenario in [success failure missing] {
                let capture = ($fixture | path join capture)
                if ($capture | path exists) { rm -r $capture }
                mkdir $capture
                let config = ($fixture | path join config.sh)
                if ($config | path exists) { rm $config }
                if $scenario != missing {
                    "DOGSTATSD_HOST='127.0.0.1'\nDOGSTATSD_PORT='18125'\nDD_TAGS='env:synthetic,team:storage'\n" | save $config
                }
                let nc_rc = (if $scenario == failure { '7' } else { '0' })
                let result = (^env -i $'PATH=($bin)' $'TMPDIR=($bin)' $'CAPTURE=($capture)' $'NC_RC=($nc_rc)' HOSTNAME=synthetic-host ZEVENT_POOL=tank ZEVENT_VDEV_PATH=/synthetic/disk0 ZEVENT_VDEV_STATE=ONLINE $interpreter ($fixture | path join $handler) | complete)
                let context = $'($shell)/($case.name)/($scenario)'
                if $scenario == missing {
                    check ($result.exit_code == (if $shell == bash { 1 } else { 2 })) $'($context): missing config exit'
                    for tool in [nc sleep curl logger] {
                        check (not ($capture | path join $tool | path exists)) $'($context): unexpected ($tool)'
                    }
                    check ($result.stderr | str contains 'config.sh') $'($context): missing diagnostic'
                } else {
                    check ($result.exit_code == (if $scenario == failure { 1 } else { 0 })) $'($context): exit'
                    let calls = (open --raw ($capture | path join nc) | lines | each { from json })
                    check (($calls | length) == 1) $'($context): exactly one datagram, no retry'
                    for tool in [sleep curl] {
                        check (not ($capture | path join $tool | path exists)) $'($context): unexpected ($tool)'
                    }
                    let call = ($calls | first)
                    check ($call.args == [-u -w0 127.0.0.1 '18125']) $'($context): nc arguments'
                    check (datagram is-event $call.input) $'($context): event datagram'
                    let event = (datagram event $call.input)
                    let expected = {
                        title: $case.title, text: $case.text, priority: $case.priority
                        alert_type: $case.alert, source: zfs
                        tags: [env:synthetic team:storage pool:tank vdev:disk0 vdev_state:ONLINE $'event_type:($case.name)']
                    }
                    check ($event == $expected) $'($context): exact event ($event | to nuon)'
                    let logs = (open --raw ($capture | path join logger) | lines | each { from json | get args })
                    let final = (if $scenario == failure { '[ERROR] Local Agent event handoff failed' } else { '[INFO] Event handed to local Agent socket' })
                    check ($logs == [[-t zfs-datadog $final]]) $'($context): logger calls ($logs | to nuon)'
                }
                $count += 1
            }
        }
    }
    print $'PASS: ($count) synthetic handler scenarios under sh/dash/bash'
}

def main [] {
    let root = ($env.CURRENT_FILE | path dirname | path join ../.. | path expand)
    let nu_exe = $nu.current-exe
    let fixture = (mktemp -d -t single-event-sender.XXXXXXXX)
    try { run-tests $root $fixture $nu_exe } catch {|err|
        rm -r $fixture
        error make {msg: $err.msg}
    }
    rm -r $fixture
}
