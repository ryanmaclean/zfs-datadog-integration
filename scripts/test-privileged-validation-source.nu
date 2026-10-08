#!/usr/bin/env nu
# Source-only guard for privileged VM test blocks after the sealed install.
def check_privileged_blocks [path: string] {
    let lines = (open --raw $path | lines)
    mut end_marker = ''
    for line in $lines {
        let trimmed = ($line | str trim)
        if $end_marker != '' {
            if $trimmed == $end_marker {
                $end_marker = ''
                continue
            }
            if ($trimmed | parse -r '^(?:\.|source)\s+/tmp/.*' | is-not-empty) {
                error make {msg: $"privileged VM block sources /tmp code in ($path): ($trimmed)"}
            }
        } else if (($line | str contains 'limactl shell') and (($line | str contains 'sudo bash <<') or ($line | str contains 'sudo sh <<'))) {
            let quoted = ($line | split row "'")
            if (($quoted | length) < 2) {
                error make {msg: $"unrecognized privileged heredoc in ($path): ($line)"}
            }
            $end_marker = ($quoted | get 1)
        }
    }
    if $end_marker != '' {
        error make {msg: $"unterminated privileged heredoc in ($path): ($end_marker)"}
    }
}

def main [repo_root: string, validation_override?: string] {
    let repo = ($repo_root | path expand)
    let validation = if $validation_override == null {
        $"($repo)/scripts/comprehensive-validation-test.sh"
    } else {
        ($validation_override | path expand)
    }
    let source = (open --raw $validation)
    let test_success = ($source | split row "<<'TEST_SUCCESS'" | get 1 | split row "\nTEST_SUCCESS" | first)
    if not ($test_success | str contains '. /etc/zfs/zed.d/config.sh') {
        error make {msg: 'root test must load the installed root-owned configuration'}
    }
    if not ($test_success | str contains '. /etc/zfs/zed.d/zfs-datadog-lib.sh') {
        error make {msg: 'root test must load the installed root-owned library'}
    }
    for script in (glob $"($repo)/scripts/*test*.sh") {
        if $script == $"($repo)/scripts/comprehensive-validation-test.sh" {
            check_privileged_blocks $validation
        } else {
            check_privileged_blocks $script
        }
    }
    print 'PASS: privileged VM test blocks do not source user-writable /tmp code; root validation loads installed postimage'
}
