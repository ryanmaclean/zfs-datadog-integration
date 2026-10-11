#!/usr/bin/env nu
# Run only as root inside the dedicated disposable off-i9 PR20 Linux VM.
# Exercise the real uninstaller against private root-owned fixtures and fault stubs.
def main [repo_root: string] {
    if ((^uname -s | str trim) != 'Linux') or ((^id -u | str trim) != '0') {
        error make {msg: 'Run this fixture as root in a disposable Linux VM'}
    }

    let repo = ($repo_root | path expand)
    let sandbox = (^mktemp -d /root/zfs-dd-uninstall-fixture.XXXXXX | str trim)
    let names = [
        zfs-datadog-lib.sh config.sh .checksum-error.sh .io-error.sh
        statechange-datadog.sh scrub_start-datadog.sh scrub_finish-datadog.sh
        resilver_start-datadog.sh resilver_finish-datadog.sh
        config_sync-datadog.sh pool_import-datadog.sh pool_destroy-datadog.sh
        vdev_attach-datadog.sh vdev_remove-datadog.sh
        ereport.fs.zfs.checksum-datadog.sh ereport.fs.zfs.io-datadog.sh
    ]

    let systemctl_stub = "#!/usr/bin/env nu
def --wrapped main [...args: string] {
    let op = ($args | first)
    $'($op)\n' | save --append $env.ZFS_TEST_OPS
    if $op == 'is-active' {
        if ((open --raw $env.ZFS_TEST_STATE | str trim) == 'active') { exit 0 }
        exit 3
    }
    if $op == 'stop' {
        let failures = (open --raw $env.ZFS_TEST_FAIL_STOP | str trim | into int)
        if $failures > 0 {
            ($failures - 1 | into string) | save --force $env.ZFS_TEST_FAIL_STOP
            exit 1
        }
        'inactive' | save --force $env.ZFS_TEST_STATE
        exit 0
    }
    if $op == 'start' {
        let failures = (open --raw $env.ZFS_TEST_FAIL_START | str trim | into int)
        if $failures > 0 {
            ($failures - 1 | into string) | save --force $env.ZFS_TEST_FAIL_START
            exit 1
        }
        'active' | save --force $env.ZFS_TEST_STATE
        exit 0
    }
    exit 2
}
"
    let rm_stub = "#!/usr/bin/env nu
def --wrapped main [...args: string] {
    let target = ($args | last)
    if ((open --raw $env.ZFS_TEST_FAIL_RM | str trim) == '1') and ($target | str ends-with '/scrub_start-datadog.sh') {
        '0' | save --force $env.ZFS_TEST_FAIL_RM
        if ((open --raw $env.ZFS_TEST_COLLISION | str trim) == '1') {
            'unknown collision\n' | save --force $'($env.ZFS_TEST_ZED_DIR)/statechange-datadog.sh'
        }
        exit 1
    }
    ^/bin/rm ...$args
}
"

    for scenario in ['rm_once', 'start_once', 'stop_once', 'restore_collision', 'start_twice'] {
        let case_dir = $"($sandbox)/($scenario)"
        let bin = $"($case_dir)/bin"
        let zed = $"($case_dir)/zed.d"
        mkdir $bin $zed
        $systemctl_stub | save $"($bin)/systemctl"
        $rm_stub | save $"($bin)/rm"
        ^chmod 755 $"($bin)/systemctl" $"($bin)/rm"
        'active' | save $"($case_dir)/state"
        (if $scenario in ['rm_once', 'restore_collision'] { '1' } else { '0' }) | save $"($case_dir)/fail-rm"
        (if $scenario == 'start_once' { '1' } else if $scenario == 'start_twice' { '2' } else { '0' }) | save $"($case_dir)/fail-start"
        (if $scenario == 'stop_once' { '1' } else { '0' }) | save $"($case_dir)/fail-stop"
        (if $scenario == 'restore_collision' { '1' } else { '0' }) | save $"($case_dir)/collision"
        '' | save $"($case_dir)/ops"

        let entries = ($names | each {|name|
            let file = $"($zed)/($name)"
            $"owned fixture for ($name)\n" | save $file
            let digest = (open --raw $file | hash sha256)
            $"($digest) ($name)"
        })
        (($entries | str join "\n") + "\n") | save $"($zed)/.zfs-datadog.manifest"
        ^chmod 600 $"($zed)/.zfs-datadog.manifest"
        let original = ($names | each {|name| {name: $name, digest: (open --raw $"($zed)/($name)" | hash sha256)}})
        let manifest_digest = (open --raw $"($zed)/.zfs-datadog.manifest" | hash sha256)

        let outcome = (with-env {
            ZED_DIR: $zed,
            PATH: ($env.PATH | prepend $bin),
            ZFS_TEST_STATE: $"($case_dir)/state",
            ZFS_TEST_FAIL_RM: $"($case_dir)/fail-rm",
            ZFS_TEST_FAIL_START: $"($case_dir)/fail-start",
            ZFS_TEST_FAIL_STOP: $"($case_dir)/fail-stop",
            ZFS_TEST_COLLISION: $"($case_dir)/collision",
            ZFS_TEST_ZED_DIR: $zed,
            ZFS_TEST_OPS: $"($case_dir)/ops"
        } {
            do { ^sh $"($repo)/scripts/uninstall.sh" } | complete
        })
        if $outcome.exit_code != 1 {
            error make {msg: $"($scenario): expected exit 1, got ($outcome.exit_code)"}
        }
        let expected_state = (if $scenario in ['restore_collision', 'start_twice'] { 'inactive' } else { 'active' })
        let state = (open --raw $"($case_dir)/state" | str trim)
        if $state != $expected_state {
            error make {msg: $"($scenario): expected ($expected_state) ZED, found ($state); inspect ($sandbox)"}
        }
        for entry in $original {
            let file = $"($zed)/($entry.name)"
            if $scenario == 'restore_collision' and $entry.name == 'statechange-datadog.sh' {
                if (open --raw $file) != "unknown collision\n" {
                    error make {msg: $"($scenario): unknown collision overwritten; inspect ($sandbox)"}
                }
            } else {
                if not ($file | path exists) or ((open --raw $file | hash sha256) != $entry.digest) {
                    error make {msg: $"($scenario): owned bytes changed or missing: ($entry.name); inspect ($sandbox)"}
                }
            }
        }
        if not ($"($zed)/.zfs-datadog.manifest" | path exists) or ((open --raw $"($zed)/.zfs-datadog.manifest" | hash sha256) != $manifest_digest) {
            error make {msg: $"($scenario): ownership manifest changed or missing; inspect ($sandbox)"}
        }
        let snapshots = (glob $"($zed)/.zfs-datadog-uninstall.*" | length)
        let expected_snapshots = (if $scenario in ['stop_once', 'restore_collision', 'start_twice'] { 1 } else { 0 })
        if $snapshots != $expected_snapshots {
            error make {msg: $"($scenario): expected ($expected_snapshots) snapshots, found ($snapshots); inspect ($sandbox)"}
        }
        let ops = (open --raw $"($case_dir)/ops" | str trim | str replace --all "\n" ',')
        print $"PASS ($scenario): exit=($outcome.exit_code), service=($state), snapshot_count=($snapshots), manifest_sha256=($manifest_digest), operations=($ops)"
    }
    print $"PASS: all five uninstall fault scenarios; guest fixture retained at ($sandbox)"
}
