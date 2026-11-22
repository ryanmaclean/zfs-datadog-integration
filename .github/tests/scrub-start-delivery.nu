#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Runs only copied zedlet/library code with synthetic inputs and Nushell transports.
# Optional source argument permits testing the pinned original without changing it.
use datagram.nu *

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
        # nc is the only transport (events and metrics are loopback datagrams).
        # curl must never run: it records a marker so the test can prove that.
        let stub = ('#!/usr/bin/env -S ' + $nu_exe + ' --no-config-file --stdin' + "\n" + '
def --wrapped main [...args: string] {
    let payload = $in
    let name = "STUB_NAME"
    if $name == "nc" {
        {args: $args, input: $payload} | to json --raw | $in + "\n" | save --append $env.CALLS
        let failed = if ($payload | str starts-with "_e{") { $env.FAIL_EVENT } else if ($payload | str contains "zfs.scrub.start:") { $env.FAIL_START } else { $env.FAIL_PROGRESS }
        if $failed == "1" { exit 7 }
    } else if $name == "curl" {
        "ran" | save --append $env.CURLS
        exit 9
    } else if $name == "sleep" {
        "ran" | save --append $env.SLEEPS
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
                    let curls = ($temp | path join 'curls')
                    let sleeps = ($temp | path join 'sleeps')
                    '' | save --force $calls
                    '' | save --force $curls
                    '' | save --force $sleeps
                    let result = (^env -i $"PATH=($temp)/bin:/usr/bin:/bin" $"TMPDIR=($temp)/bin" MONITOR_SCRUB=true ZEVENT_POOL=fake-pool ZEVENT_TIME_SECS=123 ZEVENT_EID=456 DD_TAGS=env:test HOSTNAME=fake-host DOGSTATSD_HOST=127.0.0.1 DOGSTATSD_PORT=18125 $"CALLS=($calls)" $"CURLS=($curls)" $"SLEEPS=($sleeps)" $"FAIL_START=($start)" $"FAIL_PROGRESS=($progress)" $"FAIL_EVENT=($event)" /bin/sh ($temp | path join 'scrub_start-datadog.sh') | complete)
                    let sent = (open --raw $calls | lines | where {|l| $l != '' } | each { from json })
                    let start_payload = 'zfs.scrub.start:1|c|#env:test,pool:fake-pool'
                    let progress_payload = 'zfs.scrub.in_progress:1|g|#env:test,pool:fake-pool'
                    let expected_event = {title: 'ZFS Scrub Started: fake-pool', text: 'Pool: fake-pool\nEvent ID: 456\nStarted at: 123', priority: normal, alert_type: info, source: zfs, tags: [env:test pool:fake-pool]}
                    # One datagram per sender in order (start, progress, event): failures are never retried.
                    let args_ok = ($sent | all {|s| $s.args == ['-u' '-w0' '127.0.0.1' '18125'] })
                    let shape_ok = (($sent | length) == 3) and ($sent | get 0.input) == $start_payload and ($sent | get 1.input) == $progress_payload and (datagram is-event ($sent | get 2.input))
                    let event_ok = $shape_ok and ((datagram event ($sent | get 2.input)) == $expected_event)
                    let no_curl_sleep = ((open --raw $curls) == '') and ((open --raw $sleeps) == '')
                    let failed = (($start + $progress + $event) > 0)
                    let good = ($args_ok and $shape_ok and $event_ok and $no_curl_sleep and (if $failed {
                        ($result.exit_code != 0) and ($result.stderr | str contains '[ERROR] Scrub start sender failure: pool=fake-pool eid=456') and not ($result.stderr | str contains 'Scrub start event processed:') and (($result.stderr | lines | where {|l| $l | str contains 'Local Agent metric handoff failed' } | length) == ($start + $progress)) and (($result.stderr | str contains 'Local Agent event handoff failed') == ($event == 1))
                    } else {
                        ($result.exit_code == 0) and ($result.stderr | str contains '[INFO] Scrub start event processed: pool=fake-pool eid=456') and not ($result.stderr | str contains '[ERROR]')
                    }))
                    if $good { print $"PASS ($label)" } else {
                        print $"FAIL ($label): exit=($result.exit_code) args_ok=($args_ok) shape_ok=($shape_ok) event_ok=($event_ok) no_curl_sleep=($no_curl_sleep) stderr=($result.stderr)"
                        $failures = ($failures | append $label)
                    }
                }
            }
        }
    } catch {|err|
        rm -r $temp
        error make {msg: $err.msg}
    }
    rm -r $temp
    if not ($failures | is-empty) { error make {msg: $"($failures | length)/8 cases failed"} }
    print 'PASS: 8/8 isolated cases; datagrams, argv, single attempts, exit status and logs checked'
}
