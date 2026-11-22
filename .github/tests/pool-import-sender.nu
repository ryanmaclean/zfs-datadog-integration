#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# No network: only fixture tools are reachable by the zedlet. The event leaves
# as exactly one loopback DogStatsD datagram; no retry, no sleep, no curl.
use std/assert
use datagram.nu *

def run-tests [root: path] {
    let repo = ($env.CURRENT_FILE | path dirname | path dirname | path dirname)
    let nu_bin = $nu.current-exe
    let bin = ($root | path join bin)
    mkdir $bin
    for tool in [dirname basename date cat wc mktemp rm] {
        let source = (which --all $tool | where type == external | first | get path)
        ^ln -s $source ($bin | path join $tool)
    }
    let stub = ('#!' + $nu_bin + " --no-config-file\n" + r#'
def main --wrapped [...args: string] {
    let tool = ($env.CURRENT_FILE | path basename)
    let record = ($env.FIXTURE | path join $tool)
    let input = (if $tool == "nc" { open --raw /dev/stdin } else { "" })
    ({args: $args, input: $input} | to json -r) + "\n" | save --append $record
    if $tool == "nc" and $env.NC_RC != "0" { exit ($env.NC_RC | into int) }
}
'#)
    for tool in [nc curl logger sleep] {
        let target = ($bin | path join $tool)
        $stub | save $target
        ^chmod +x $target
    }
    let expected = {
        title: "ZFS Pool Imported: fixture-pool"
        text: "Pool fixture-pool has been imported on host fixture-host"
        priority: low
        alert_type: info
        source: zfs
        tags: ["env:fixture" "team:storage" "pool:fixture-pool" "vdev:fixture-disk" "vdev_state:ONLINE" "event_type:pool_import"]
    }
    mut cases = 0
    for shell in [sh dash bash] {
        let interpreter = (which $shell | first | get path)
        for case in [
            {name: success, rc: "0", code: 0, datagrams: 1}
            {name: handoff-failure, rc: "7", code: 1, datagrams: 1}
            {name: missing-config, rc: "0", code: null, datagrams: 0}
        ] {
            let dir = ($root | path join $"($shell)-($case.name)")
            mkdir $dir
            cp ($repo | path join scripts/pool_import-datadog.sh) $dir
            cp ($repo | path join scripts/zfs-datadog-lib.sh) $dir
            if $case.name != missing-config {
                "DOGSTATSD_HOST=127.0.0.1\nDOGSTATSD_PORT=18125\nDD_TAGS=env:fixture,team:storage\nHOSTNAME=fixture-host\n" | save ($dir | path join config.sh)
            }
            let result = (^env -i $"PATH=($bin)" $"TMPDIR=($bin)" $"FIXTURE=($dir)" $"NC_RC=($case.rc)" HOSTNAME=fixture-host ZEVENT_POOL=fixture-pool ZEVENT_VDEV_PATH=/synthetic/fixture-disk ZEVENT_VDEV_STATE=ONLINE $interpreter ($dir | path join pool_import-datadog.sh) | complete)
            if $case.code == null {
                assert ($result.exit_code != 0) $"($shell): missing config must fail"
            } else {
                assert equal $result.exit_code $case.code
            }
            let nc_file = ($dir | path join nc)
            let calls = if ($nc_file | path exists) { open --raw $nc_file | lines | each { from json } } else { [] }
            assert equal ($calls | length) $case.datagrams
            for call in $calls {
                assert equal $call.args ["-u" "-w0" "127.0.0.1" "18125"]
                assert (datagram is-event $call.input)
                assert equal (datagram event $call.input) $expected
            }
            for tool in [curl sleep] {
                assert (not ($dir | path join $tool | path exists)) $"($shell) ($case.name): unexpected ($tool)"
            }
            let log_file = ($dir | path join logger)
            if $case.datagrams > 0 {
                let logs = (open --raw $log_file | lines | each { from json | get args | last })
                assert equal ($logs | length) 1
                if $case.code == 0 {
                    assert equal $logs.0 "[INFO] Event handed to local Agent socket"
                } else {
                    assert equal $logs.0 "[ERROR] Local Agent event handoff failed"
                }
            } else {
                assert (not ($log_file | path exists))
            }
            $cases += 1
            print $"PASS ($shell) ($case.name)"
        }
    }
    print $"PASS all ($cases) isolated cases; synthetic submission only, no intake assertion"
}

def main [] {
    let root = (^mktemp -d | str trim)
    try {
        run-tests $root
    } catch {|err|
        rm -rf $root
        error make {msg: $err.msg}
    }
    rm -rf $root
}
