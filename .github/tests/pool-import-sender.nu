#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# No network: only fixture tools are reachable by the zedlet.
use std/assert

def run-tests [root: path] {
    let repo = ($env.CURRENT_FILE | path dirname | path dirname | path dirname)
    let nu_bin = $nu.current-exe
    let bin = ($root | path join bin)
    mkdir $bin
    for tool in [dirname basename date cat] {
        let source = ("/usr/bin" | path join $tool)
        ^ln -s $source ($bin | path join $tool)
    }
    let stub = ('#!' + $nu_bin + " --no-config-file\n" + r#'
def main --wrapped [...args: string] {
    let tool = ($env.CURRENT_FILE | path basename)
    let record = ($env.FIXTURE | path join $tool)
    ($args | to json -r) | save --append $record
    "\n" | save --append $record
    if $tool == "curl" {
        let calls = (open --raw $record | lines | length)
        print -n "202"
        if $calls <= ($env.FAIL_COUNT | into int) { exit 7 }
    }
}
'#)
    for tool in [curl logger sleep] {
        let target = ($bin | path join $tool)
        $stub | save $target
        ^chmod +x $target
    }
    let expected = {
        title: "ZFS Pool Imported: fixture-pool"
        text: "Pool fixture-pool has been imported on host fixture-host"
        priority: low
        tags: ["env:fixture" "team:storage" "pool:fixture-pool" "vdev:fixture-disk" "vdev_state:ONLINE" "event_type:pool_import"]
        alert_type: info
        source_type_name: zfs
        host: fixture-host
    }
    for shell in [sh dash bash] {
        let interpreter = (which $shell | first | get path)
        for case in [
            {name: success, failures: 0, attempts: 1, code: 0, waits: []}
            {name: retry-success, failures: 2, attempts: 3, code: 0, waits: ["1" "2"]}
            {name: exhausted, failures: 3, attempts: 3, code: 1, waits: ["1" "2"]}
            {name: missing-config, failures: 0, attempts: 0, code: null, waits: []}
        ] {
            let dir = ($root | path join $"($shell)-($case.name)")
            mkdir $dir
            cp ($repo | path join scripts/pool_import-datadog.sh) $dir
            cp ($repo | path join scripts/zfs-datadog-lib.sh) $dir
            if $case.name != missing-config {
                "DD_API_KEY=synthetic-key\nDD_API_URL=https://fixture.invalid\nDD_TAGS=env:fixture,team:storage\nHOSTNAME=fixture-host\n" | save ($dir | path join config.sh)
            }
            let result = (^env -i $"PATH=($bin)" $"FIXTURE=($dir)" $"FAIL_COUNT=($case.failures)" HOSTNAME=fixture-host ZEVENT_POOL=fixture-pool ZEVENT_VDEV_PATH=/synthetic/fixture-disk ZEVENT_VDEV_STATE=ONLINE $interpreter ($dir | path join pool_import-datadog.sh) | complete)
            if $case.code == null {
                assert ($result.exit_code != 0) $"($shell): missing config must fail"
            } else {
                assert equal $result.exit_code $case.code
            }
            let curl_file = ($dir | path join curl)
            let calls = if ($curl_file | path exists) { open --raw $curl_file | lines | each { from json } } else { [] }
            assert equal ($calls | length) $case.attempts
            for argv in $calls {
                # #40 may add precisely these output/status options.
                mut normalized = []
                mut i = 0
                while $i < ($argv | length) {
                    let arg = ($argv | get $i)
                    if $arg in ["-o" "-w"] {
                        let value = ($argv | get ($i + 1))
                        assert equal $value (if $arg == "-o" { "/dev/null" } else { "%{http_code}" })
                        $i = $i + 2
                    } else {
                        $normalized = ($normalized | append $arg)
                        $i = $i + 1
                    }
                }
                assert equal ($normalized | first 11) ["-s" "-m" "10" "-X" "POST" "https://fixture.invalid/api/v1/events" "-H" "Content-Type: application/json" "-H" "DD-API-KEY: synthetic-key" "-d"]
                assert equal ($normalized | length) 12
                assert equal ($normalized | last | from json) $expected
            }
            let sleep_file = ($dir | path join sleep)
            let waits = if ($sleep_file | path exists) { open --raw $sleep_file | lines | each { from json | first } } else { [] }
            assert equal $waits $case.waits
            let log_file = ($dir | path join logger)
            if $case.attempts > 0 {
                let logs = (open --raw $log_file | lines | each { from json | last })
                assert equal ($logs | length) $case.attempts
                if $case.code == 0 {
                    assert ($logs | last | str contains "[INFO] Event sent")
                } else {
                    assert ($logs | last | str contains "[ERROR] Failed to send event after 3 attempts")
                }
            } else {
                assert (not ($log_file | path exists))
            }
            print $"PASS ($shell) ($case.name)"
        }
    }
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
    print "PASS all 12 isolated cases; synthetic submission only, no intake assertion"
}
