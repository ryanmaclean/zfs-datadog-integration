#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Runs only copied zedlet/library code with synthetic inputs and Nushell transports.
# Optional source argument permits testing the pinned original without changing it.
def main [source?: path] {
    let root = ($env.FILE_PWD | path join '../..' | path expand)
    let target = ($source | default ($root | path join 'scripts/scrub_start-datadog.sh'))
    let nu_exe = $nu.current-exe
    let temp = (mktemp -d)
    mut failures = []
    try {
        cp $target ($temp | path join 'scrub_start-datadog.sh')
        cp ($root | path join 'scripts/zfs-datadog-lib.sh') $temp
        mkdir ($temp | path join 'bin')
        let stub = ('#!/usr/bin/env -S ' + $nu_exe + ' --no-config-file --stdin' + "\n" + '
def --wrapped main [...args: string] {
    let payload = $in
    let name = "STUB_NAME"
    if $name == "nc" {
        $payload | save --append $env.CALLS
        let failed = if ($payload | str contains "zfs.scrub.start:") { $env.FAIL_START } else { $env.FAIL_PROGRESS }
        if $failed == "1" { exit 7 }
    } else if $name == "curl" {
        let normalized = if (($args | slice 1..4) == ["-o" "/dev/null" "-w" "%{http_code}"]) { $args | enumerate | where {|x| $x.index < 1 or $x.index > 4 } | get item } else { $args }
        ($normalized | to json --raw) | save --append $env.EVENTS
        if $env.FAIL_EVENT == "1" { exit 8 }
        print -n "202"
    } else if $name == "date" {
        print "2000-01-01 00:00:00"
    }
}
')
        for name in [nc curl sleep logger date] {
            let path = ($temp | path join 'bin' $name)
            $stub | str replace STUB_NAME $name | save $path
            ^chmod +x $path
        }
        for start in [0 1] {
            for progress in [0 1] {
                for event in [0 1] {
                    let label = $"start=($start) progress=($progress) event=($event)"
                    let calls = ($temp | path join 'calls')
                    let events = ($temp | path join 'events')
                    '' | save --force $calls
                    '' | save --force $events
                    let result = (^env -i $"PATH=($temp)/bin:/usr/bin:/bin" MONITOR_SCRUB=true ZEVENT_POOL=fake-pool ZEVENT_TIME=123 ZEVENT_EID=456 DD_API_KEY=fake-only DD_TAGS=env:test HOSTNAME=fake-host $"CALLS=($calls)" $"EVENTS=($events)" $"FAIL_START=($start)" $"FAIL_PROGRESS=($progress)" $"FAIL_EVENT=($event)" /bin/sh ($temp | path join 'scrub_start-datadog.sh') | complete)
                    let metrics = (open --raw $calls)
                    let requests = (open --raw $events)
                    let start_payload = 'zfs.scrub.start:1|c|#env:test,pool:fake-pool,host:fake-host'
                    let progress_payload = 'zfs.scrub.in_progress:1|g|#env:test,pool:fake-pool,host:fake-host'
                    let expected_metrics = ((0..<(1 + $start) | each { $start_payload } | str join) + (0..<(1 + $progress) | each { $progress_payload } | str join))
                    let expected_event = ['-s' '-m' '10' '-X' 'POST' 'https://api.datadoghq.com/api/v1/events' '-H' 'Content-Type: application/json' '-H' 'DD-API-KEY: fake-only' '-d' "{\n  \"title\": \"ZFS Scrub Started: fake-pool\",\n  \"text\": \"Pool: fake-pool\\nEvent ID: 456\\nStarted at: 123\",\n  \"priority\": \"normal\",\n  \"tags\": [\"env:test\",\"pool:fake-pool\"],\n  \"alert_type\": \"info\",\n  \"source_type_name\": \"zfs\",\n  \"host\": \"fake-host\"\n}"]
                    let expected_requests = (0..<(if $event == 1 { 3 } else { 1 }) | each { $expected_event | to json --raw } | str join)
                    let failed = (($start + $progress + $event) > 0)
                    let good = (($metrics == $expected_metrics) and ($requests == $expected_requests) and (if $failed {
                        ($result.exit_code != 0) and ($result.stderr | str contains '[ERROR] Scrub start sender failure: pool=fake-pool eid=456') and not ($result.stderr | str contains 'Scrub start event processed:')
                    } else {
                        ($result.exit_code == 0) and ($result.stderr | str contains '[INFO] Scrub start event processed: pool=fake-pool eid=456') and not ($result.stderr | str contains '[ERROR]')
                    }))
                    if $good { print $"PASS ($label)" } else {
                        print $"FAIL ($label): exit=($result.exit_code) metrics_match=($metrics == $expected_metrics) event_match=($requests == $expected_requests)"
                        $failures = ($failures | append $label)
                    }
                }
            }
        }
    } catch {|err|
        rm -rf $temp
        error make {msg: $err.msg}
    }
    rm -rf $temp
    if not ($failures | is-empty) { error make {msg: $"($failures | length)/8 cases failed"} }
    print 'PASS: 8/8 isolated cases; all sends, arguments, retry counts, exit status and logs checked'
}
