#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Actual completion handlers, synthetic transports, no real config or ZFS calls.
use std/assert
use datagram.nu *

def main [] {
    let repo = ($env.FILE_PWD | path join ../.. | path expand)
    let work = (mktemp -d | str trim)
    try {
        let bin = ($work | path join bin)
        mkdir $bin
        for tool in [dirname basename date cat cut wc] {
            ^ln -s (which --all $tool | where type == external | first | get path) ($bin | path join $tool)
        }
        for name in [zfs-datadog-lib.sh scrub_finish-datadog.sh resilver_finish-datadog.sh] {
            cp ($repo | path join scripts $name) $work
        }
        let stub = ($'#!($nu.current-exe) --no-config-file' + "\n" + '
def main --wrapped [...args: string] {
    let tool = ($env.CURRENT_FILE | path basename)
    if $tool == "nc" {
        if $args != ["-u" "-w1" "127.0.0.1" "18125"] { error make {msg: "unexpected nc argv"} }
        let packet = (open --raw /dev/stdin)
        $packet + "\n" | save --append $env.METRICS
        let is_event = ($packet | str starts-with "_e{")
        if $env.FAIL == "event" and $is_event { exit 1 }
        if $env.FAIL == "progress" and ($packet | str contains ".in_progress:") { exit 1 }
    } else if $tool == "sleep" {
        error make {msg: "unexpected retry"}
    }
}
')
        for tool in [nc logger sleep] {
            $stub | save ($bin | path join $tool)
            ^chmod +x ($bin | path join $tool)
        }
        let cases = ('[
  {
    "errors": null,
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "3700",
    "expected_errors": "0",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "0000",
    "start": "100",
    "end": "3700",
    "expected_errors": "0",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "2",
    "start": "100",
    "end": "3700",
    "expected_errors": "2",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "0002",
    "start": "100",
    "end": "3700",
    "expected_errors": "2",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "18446744073709551615",
    "start": "100",
    "end": "3700",
    "expected_errors": "18446744073709551615",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "18446744073709551616",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "999999999999999999999",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "-1",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "+1",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "1.5",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": " 2",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "2 ",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "2\n3",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "\"injected\":true",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "$(touch never-run)",
    "start": "100",
    "end": "3700",
    "expected_errors": "unknown",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "0",
    "start": null,
    "end": "3700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "100",
    "end": null,
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "",
    "end": "3700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "bad",
    "end": "3700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "bad",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "-1",
    "end": "3700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "+3700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "0",
    "end": "3700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "0",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "3700",
    "end": "100",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "100",
    "expected_errors": "0",
    "duration": "0",
    "duration_text": "0h 0m"
  },
  {
    "errors": "0",
    "start": "000100",
    "end": "003700",
    "expected_errors": "0",
    "duration": "3600",
    "duration_text": "1h 0m"
  },
  {
    "errors": "0",
    "start": "9223372036854775808",
    "end": "9223372036854775808",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "1",
    "end": "9223372036854775808",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": "0",
    "start": "9223372036854775806",
    "end": "9223372036854775807",
    "expected_errors": "0",
    "duration": "1",
    "duration_text": "0h 0m"
  },
  {
    "errors": "0",
    "start": "1",
    "end": "9223372036854775807",
    "expected_errors": "0",
    "duration": "9223372036854775806",
    "duration_text": "2562047788015215h 30m"
  },
  {
    "errors": "0",
    "start": "100",
    "end": "000000000000000003700",
    "expected_errors": "0",
    "duration": "unknown",
    "duration_text": "unknown"
  },
  {
    "errors": null,
    "start": null,
    "end": null,
    "expected_errors": "unknown",
    "duration": "unknown",
    "duration_text": "unknown",
    "fail": "none"
  },
  {
    "errors": null,
    "start": null,
    "end": null,
    "expected_errors": "unknown",
    "duration": "unknown",
    "duration_text": "unknown",
    "fail": "event"
  },
  {
    "errors": null,
    "start": null,
    "end": null,
    "expected_errors": "unknown",
    "duration": "unknown",
    "duration_text": "unknown",
    "fail": "progress"
  }
]' | from json)
        mut count = 0
        for shell in [sh dash bash] {
            let executable = (which $shell | first | get path)
            for scan in [scrub resilver] {
                for case in $cases {
                    let metrics = ($work | path join metrics)
                    '' | save -f $metrics
                    mut value_env = []
                    for field in [errors start end] {
                        let value = ($case | get $field)
                        if $value != null { $value_env = ($value_env | append $'ZEVENT_POOL_($scan | str upcase)_($field | str upcase)=($value)') }
                    }
                    let failure = ($case.fail? | default 'none')
                    let result = (^env -i $'PATH=($bin)' HOSTNAME=fixture DD_TAGS=env:test DOGSTATSD_HOST=127.0.0.1 DOGSTATSD_PORT=18125 MONITOR_SCRUB=true MONITOR_RESILVER=true ZEVENT_POOL=tank $'FAIL=($failure)' $'METRICS=($metrics)' ZEVENT_EID=42 ...$value_env $executable ($work | path join $'($scan)_finish-datadog.sh') | complete)
                    let context = $'($shell)/($scan)/($case | to nuon)'
                    assert equal $result.exit_code (if $failure == 'none' { 0 } else { 1 }) $'exit: ($context): ($result | to nuon)'
                    assert equal $result.stdout '' $'stdout: ($context): ($result | to nuon)'
                    let lines = (open --raw $metrics | lines)
                    let packets = ($lines | where {|l| datagram is-event $l })
                    assert equal ($packets | length) 1 $'one event datagram: ($context)'
                    let payload = (datagram event ($packets | first))
                    let status = (if $case.expected_errors == unknown { 'completed (result unknown)' } else if $case.expected_errors == '0' { 'completed successfully' } else { 'completed with errors' })
                    let alert = (if $case.expected_errors == unknown { 'info' } else if $case.expected_errors == '0' { 'success' } else { 'error' })
                    assert ($result.stderr | lines | all {|line| $line | str starts-with '[' }) $'unexpected shell diagnostic: ($context): ($result | to nuon)'
                    assert equal $payload.text $'Pool: tank\nEvent ID: 42\nStatus: ($status)\nErrors Found: ($case.expected_errors)\nDuration: ($case.duration_text)' $'payload: ($context): ($payload | to nuon)'
                    assert equal $payload.alert_type $alert $'alert: ($context): ($payload | to nuon)'
                    assert equal $payload.tags [env:test pool:tank] $'tags: ($context)'
                    mut expected_metrics = []
                    if $case.expected_errors != unknown { $expected_metrics = ($expected_metrics | append $'zfs.($scan).errors:($case.expected_errors)|g|#env:test,pool:tank') }
                    if $case.duration != unknown and $case.duration != '0' { $expected_metrics = ($expected_metrics | append $'zfs.($scan).duration:($case.duration)|g|#env:test,pool:tank') }
                    # The library never retries: a failed progress handoff is still one datagram.
                    $expected_metrics = ($expected_metrics | append $'zfs.($scan).in_progress:0|g|#env:test,pool:tank')
                    let actual_metrics = ($lines | where {|l| not (datagram is-event $l) })
                    assert equal $actual_metrics $expected_metrics $'metrics: ($context): ($actual_metrics | to nuon)'
                    $count += 1
                }
            }
        }
        print $'PASS: ($count) actual-handler synthetic finish-result cases across sh/dash/bash'
    } catch {|err| rm -r $work; error make {msg: $err.msg} }
    rm -r $work
}
