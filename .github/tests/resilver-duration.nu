#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Standalone, offline regression. Only the copied zedlet/library and recording
# Nushell stubs run; env -i prevents inherited configuration or credentials.
def main [] {
    let root = ($env.CURRENT_FILE | path dirname | path dirname | path dirname)
    let work = (mktemp -d -t resilver-duration.XXXXXXXX)
    let runner = $nu.current-exe
    try {
        let bin = ($work | path join bin)
        let zed = ($work | path join zed)
        mkdir $bin $zed
        for name in [resilver_finish-datadog.sh zfs-datadog-lib.sh] {
            cp ($root | path join scripts $name) $zed
        }
        for name in [dirname cat cut] {
            ^ln -s ($"/usr/bin/($name)") ($bin | path join $name)
        }
        let stubs = {
            curl: 'def --wrapped main [...args: string] {
    let i = ($args | enumerate | where item == "-d" | first | get index)
    ($args | get ($i + 1)) | save --force $env.EVENT_LOG
    print -n "202"
}'
            nc: 'def --wrapped main [...args: string] { open --raw /dev/stdin | save --append $env.METRIC_LOG; "
" | save --append $env.METRIC_LOG }'
            logger: 'def --wrapped main [...args: string] {}'
            date: 'def --wrapped main [...args: string] { print "2000-01-01 00:00:00" }'
            sleep: 'def --wrapped main [...args: string] { error make {msg: "unexpected retry"} }'
        }
        for stub in ($stubs | transpose name body) {
            let file = ($bin | path join $stub.name)
            $"#!($runner) --no-config-file
($stub.body)
" | save $file
            ^chmod +x $file
        }
        let cases = [
            {name: unset-start, start: null, end: "1700007384"}
            {name: empty-start, start: "", end: "1700007384"}
            {name: unset-end, start: "1700000000", end: null}
            {name: empty-end, start: "1700000000", end: ""}
            {name: unset-both, start: null, end: null}
            {name: empty-both, start: "", end: ""}
            {name: unset-start-empty-end, start: null, end: ""}
            {name: empty-start-unset-end, start: "", end: null}
            {name: valid, start: "1700000000", end: "1700007384"}
        ]
        mut failures = []
        for shell in [sh dash bash] {
            for case in $cases {
                let event = ($work | path join event.json)
                if ($event | path exists) { rm $event }
                let metrics = ($work | path join metrics)
                "" | save --force $metrics
                mut vars = [
                    $"PATH=($bin)" $"HOME=($work)"
                    $"EVENT_LOG=($event)" $"METRIC_LOG=($metrics)"
                    "DD_API_KEY=fake-test-key" "DD_API_URL=https://example.invalid"
                    "HOSTNAME=test-host" "DD_TAGS=env:test"
                    "MONITOR_RESILVER=true" "ZEVENT_POOL=fake-pool"
                    "ZEVENT_POOL_RESILVER_ERRORS=0"
                ]
                if $case.start != null { $vars = ($vars | append $"ZEVENT_POOL_RESILVER_START=($case.start)") }
                if $case.end != null { $vars = ($vars | append $"ZEVENT_POOL_RESILVER_END=($case.end)") }
                let result = (^/usr/bin/env -i ...$vars $"/bin/($shell)" ($zed | path join resilver_finish-datadog.sh) | complete)
                if not ($event | path exists) { error make {msg: $"zedlet failed: ($result | to nuon)"} }
                let valid = ($case.name == "valid")
                let expected = (if $valid { "2h 3m" } else { "unknown" })
                let payload = (open --raw $event | from json)
                let lines = (open --raw $metrics | lines)
                let duration = ($lines | where {str starts-with "zfs.resilver.duration:"})
                let ok = ($result.exit_code == 0 and
                    ($payload.text | str ends-with $"Duration: ($expected)") and
                    $payload.alert_type == "success" and
                    ($payload.text | str contains "Status: completed successfully") and
                    ($lines | where {str starts-with "zfs.resilver.errors:0|g|"} | length) == 1 and
                    ($lines | where {str starts-with "zfs.resilver.in_progress:0|g|"} | length) == 1 and
                    ($lines | length) == (if $valid { 3 } else { 2 }) and
                    (if $valid {
                        ($duration | length) == 1 and ($duration.0 | str starts-with "zfs.resilver.duration:7384|g|")
                    } else { ($duration | is-empty) }))
                print $"(if $ok { 'PASS' } else { 'FAIL' }) ($shell)/($case.name)"
                if not $ok { $failures = ($failures | append $"($shell)/($case.name)") }
            }
        }
        if not ($failures | is-empty) {
            error make {msg: $"($failures | length) of 27 cases failed"}
        }
        print "PASS: all 27 cases"
    } catch {|err|
        rm -rf $work
        error make {msg: $err.msg}
    }
    rm -rf $work
}
