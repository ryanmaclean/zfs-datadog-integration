#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Synthetic integration tests: no network client or pool utility in PATH.
def check [ok: bool, message: string] {
    if not $ok { error make {msg: $message} }
}

def run-tests [root: string, fixture: string, nu_exe: string] {
    let bin = ($fixture | path join bin)
    mkdir $bin
    for tool in [dirname basename date cat] {
        let target = ('/usr/bin' | path join $tool)
        ^ln -s $target ($bin | path join $tool)
    }
    let stub = ('#!' + $nu_exe + " --no-config-file\n" + 'def --wrapped main [...args: string] {
    let name = ($env.CURRENT_FILE | path basename)
    let file = ($env.CAPTURE | path join $name)
    let old = (if ($file | path exists) { open --raw $file | from json } else { [] })
    $old | append [$args] | to json | save --force $file
    if $name == "curl" {
        print "202"
        if (($old | length) < ($env.FAILURES | into int)) { exit 7 }
    }
}
')
    for tool in [curl logger sleep] {
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
            for scenario in [success retry exhausted missing] {
                let capture = ($fixture | path join capture)
                if ($capture | path exists) { rm -r $capture }
                mkdir $capture
                let config = ($fixture | path join config.sh)
                if ($config | path exists) { rm $config }
                if $scenario != missing {
                    "DD_API_KEY='synthetic-key'\nDD_API_URL='https://synthetic.invalid'\nDD_TAGS='env:synthetic,team:storage'\n" | save $config
                }
                let failures = (match $scenario { retry => 1, exhausted => 3, _ => 0 })
                let result = (^env -i $'PATH=($bin)' $'CAPTURE=($capture)' $'FAILURES=($failures)' HOSTNAME=synthetic-host ZEVENT_POOL=tank ZEVENT_VDEV_PATH=/synthetic/disk0 ZEVENT_VDEV_STATE=ONLINE $interpreter ($fixture | path join $handler) | complete)
                let context = $'($shell)/($case.name)/($scenario)'
                if $scenario == missing {
                    check ($result.exit_code == (if $shell == bash { 1 } else { 2 })) $'($context): missing config exit'
                    check (not ($capture | path join curl | path exists)) $'($context): unexpected curl'
                    check (not ($capture | path join sleep | path exists)) $'($context): unexpected sleep'
                    check (not ($capture | path join logger | path exists)) $'($context): unexpected logger'
                    check ($result.stderr | str contains 'config.sh') $'($context): missing diagnostic'
                } else {
                    check ($result.exit_code == (if $scenario == exhausted { 1 } else { 0 })) $'($context): exit'
                    let calls = (open --raw ($capture | path join curl) | from json)
                    let attempts = (match $scenario { success => 1, retry => 2, _ => 3 })
                    check (($calls | length) == $attempts) $'($context): attempts'
                    let payload = {
                        title: $case.title, text: $case.text, priority: $case.priority,
                        tags: [env:synthetic team:storage pool:tank vdev:disk0 vdev_state:ONLINE $'event_type:($case.name)'],
                        alert_type: $case.alert, source_type_name: zfs, host: synthetic-host
                    }
                    for call in $calls {
                        # #40 adds exactly these output/status pairs at the front.
                        let args = (if (($call | take 5) == [-s -o /dev/null -w '%{http_code}']) { [-s ...($call | skip 5)] } else { $call })
                        check (($args | take 12) == [-s -m '10' -X POST 'https://synthetic.invalid/api/v1/events' -H 'Content-Type: application/json' -H 'DD-API-KEY: synthetic-key' -d ($args | last)] and ($args | length) == 12) $'($context): curl arguments'
                        check (($args | last | from json) == $payload) $'($context): exact payload'
                    }
                    let sleeps = (if ($capture | path join sleep | path exists) { open --raw ($capture | path join sleep) | from json } else { [] })
                    let expected = (match $scenario { success => [], retry => [['1']], _ => [['1'] ['2']] })
                    check ($sleeps == $expected) $'($context): backoff'
                    let logs = (open --raw ($capture | path join logger) | from json | each {|log|
                        if $log == [-t zfs-datadog '[ERROR] Failed to send event after 3 attempts: 202'] {
                            [-t zfs-datadog '[ERROR] Failed to send event after 3 attempts']
                        } else { $log }
                    })
                    mut expected_logs = []
                    for index in ($expected | enumerate) {
                        let attempt = ($index.index + 1)
                        if $attempt < $attempts {
                            let wait = (if $attempt == 1 { 1 } else { 2 })
                            $expected_logs = ($expected_logs | append [[-t zfs-datadog ('[WARN] Failed to send event (attempt ' + ($attempt | into string) + '/3), retrying in ' + ($wait | into string) + 's...')]])
                        }
                    }
                    let final = (if $scenario == exhausted { '[ERROR] Failed to send event after 3 attempts' } else { $'[INFO] Event sent to Datadog: ($case.title)' })
                    $expected_logs = ($expected_logs | append [[-t zfs-datadog $final]])
                    check ($logs == $expected_logs) $'($context): logger calls'
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
