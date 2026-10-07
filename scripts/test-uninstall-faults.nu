#!/usr/bin/env nu
# Run only as root inside an approved disposable off-i9 Linux VM.
# Exercises the real uninstaller with fake systemctl and one-shot rm/start faults.
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
def main [...args: string] {
    let op = ($args | first)
    if $op == 'is-active' {
        if ((open --raw $env.ZFS_TEST_STATE | str trim) == 'active') { exit 0 }
        exit 3
    }
    if $op == 'stop' {
        'inactive' | save --force $env.ZFS_TEST_STATE
        exit 0
    }
    if $op == 'start' {
        if ((open --raw $env.ZFS_TEST_FAIL_START | str trim) == '1') {
            '0' | save --force $env.ZFS_TEST_FAIL_START
            exit 1
        }
        'active' | save --force $env.ZFS_TEST_STATE
        exit 0
    }
    exit 2
}
"
    let rm_stub = "#!/usr/bin/env nu
def main [...args: string] {
    let target = ($args | last)
    if ((open --raw $env.ZFS_TEST_FAIL_RM | str trim) == '1') and ($target | str ends-with '/scrub_start-datadog.sh') {
        '0' | save --force $env.ZFS_TEST_FAIL_RM
        exit 1
    }
    rm ...$args
}
"

    for scenario in ['rm_once', 'start_once'] {
        let case_dir = $"($sandbox)/($scenario)"
        let bin = $"($case_dir)/bin"
        let zed = $"($case_dir)/zed.d"
        mkdir $bin $zed
        $systemctl_stub | save $"($bin)/systemctl"
        $rm_stub | save $"($bin)/rm"
        ^chmod 755 $"($bin)/systemctl" $"($bin)/rm"
        'active' | save $"($case_dir)/state"
        (if $scenario == 'rm_once' { '1' } else { '0' }) | save $"($case_dir)/fail-rm"
        (if $scenario == 'start_once' { '1' } else { '0' }) | save $"($case_dir)/fail-start"

        let entries = ($names | each {|name|
            let file = $"($zed)/($name)"
            $"owned fixture for ($name)\n" | save $file
            let digest = (open --raw $file | hash sha256)
            $"($digest) ($name)"
        })
        (($entries | str join "\n") + "\n") | save $"($zed)/.zfs-datadog.manifest"
        ^chmod 600 $"($zed)/.zfs-datadog.manifest"

        with-env {
            ZED_DIR: $zed,
            PATH: $"($bin):($env.PATH)",
            ZFS_TEST_STATE: $"($case_dir)/state",
            ZFS_TEST_FAIL_RM: $"($case_dir)/fail-rm",
            ZFS_TEST_FAIL_START: $"($case_dir)/fail-start"
        } {
            ^sh $"($repo)/scripts/uninstall.sh"
            if $env.LAST_EXIT_CODE == 0 {
                error make {msg: $"($scenario): injected fault was not reported"}
            }
        }
        if ((open --raw $"($case_dir)/state" | str trim) != 'active') {
            error make {msg: $"($scenario): ZED was not restored active; inspect ($sandbox)"}
        }
        for name in $names {
            if not ($"($zed)/($name)" | path exists) {
                error make {msg: $"($scenario): missing restored ($name); inspect ($sandbox)"}
            }
        }
        if not ($"($zed)/.zfs-datadog.manifest" | path exists) {
            error make {msg: $"($scenario): ownership manifest missing after recovery; inspect ($sandbox)"}
        }
        if ((glob $"($zed)/.zfs-datadog-uninstall.*" | length) != 0) {
            error make {msg: $"($scenario): snapshot remains after successful recovery; inspect ($sandbox)"}
        }
    }
    rm --recursive --force $sandbox
    print 'PASS: partial rm and first start failure returned nonzero, restored owned files, and left ZED active'
}
