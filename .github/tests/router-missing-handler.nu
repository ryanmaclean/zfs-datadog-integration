# SPDX-License-Identifier: MIT
# Run from the repository root with nu --no-config-file.
# Only the router is copied; real handlers are never loaded.
use std/assert

def check [shell: string, root: path, event: any, code: int, output: string, error: string] {
    let router = ($root | path join 'all-datadog.sh')
    let log = ($root | path join 'logger.txt')
    '' | save -f $log
    let vars = {PATH: ($root | path join 'bin'), ZEVENT_CLASS: ($event | default ''), ROUTER_LOG: $log}
    let result = (with-env $vars {
        if $event == null { hide-env ZEVENT_CLASS }
        ^$shell $router ignored-argument | complete
    })
    assert equal $result.exit_code $code
    assert equal $result.stdout $output
    assert equal $result.stderr $error
    let logged = (open --raw $log)
    if ($event != null) and ($event != '') {
        assert not ($logged | str contains $event)
    }
}

def main [] {
    assert equal (version).version '0.115.1'
    let nu_path = $nu.current-exe
    let source = ('scripts/all-datadog.sh' | path expand)
    let shells = ([sh dash bash] | each {|name| which $name | first | get path })
    let root = (^mktemp -d | str trim)
    try {
        mkdir ($root | path join 'bin')
        cp $source ($root | path join 'all-datadog.sh')
        # No shell stubs: logger and both handlers are temporary Nu programs.
        let logger = ($root | path join 'bin/logger')
        $'#!($nu_path) --no-config-file
def --wrapped main [...args: string] {
    $args | str join " " | save -f $env.ROUTER_LOG
}
' | save $logger
        ^chmod 700 $logger
        ^ln -s /usr/bin/dirname ($root | path join 'bin/dirname')
        for shell in $shells {
            for kind in [checksum io] {
                let handler = ($root | path join $'($kind)-error.sh')
                let other = (if $kind == checksum { 'io' } else { 'checksum' })
                let decoy = ($root | path join $'($other)-error.sh')
                $'#!($nu_path) --no-config-file
print -n "wrong-handler"
exit 99
' | save -f $decoy
                ^chmod 700 $decoy
                let diagnostic = $'zfs-datadog: ($kind) handler unavailable(char nl)'
                for state in [missing non-executable executable] {
                    if $state != missing {
                        $'#!($nu_path) --no-config-file
use std/assert
assert equal $env.ZEVENT_CLASS "ereport.fs.zfs.($kind)"
print -n "($kind)"
exit 37
' | save -f $handler
                        ^chmod (if $state == executable { '700' } else { '600' }) $handler
                    }
                    check $shell $root $'ereport.fs.zfs.($kind)' (if $state == executable { 37 } else { 1 }) (if $state == executable { $kind } else { '' }) (if $state == executable { '' } else { $diagnostic })
                }
                # Zero must propagate too; no arguments are forwarded by exec.
                $'#!($nu_path) --no-config-file
def --wrapped main [...args: string] {
    if $args != [] { exit 98 }
    print -n "($kind)"
    exit 0
}
' | save -f $handler
                check $shell $root $'ereport.fs.zfs.($kind)' 0 $kind ''
                rm $handler $decoy
            }
            # Both substrings: checksum wins even when the I/O handler exists.
            let io = ($root | path join 'io-error.sh')
            $'#!($nu_path) --no-config-file
print -n "wrong-handler"
exit 99
' | save -f $io
            ^chmod 700 $io
            check $shell $root 'io.checksum.private-marker' 1 '' $'zfs-datadog: checksum handler unavailable(char nl)'
            let checksum = ($root | path join 'checksum-error.sh')
            $'#!($nu_path) --no-config-file
print -n "checksum"
exit 42
' | save -f $checksum
            ^chmod 600 $checksum
            check $shell $root 'io.checksum.private-marker' 1 '' $'zfs-datadog: checksum handler unavailable(char nl)'
            ^chmod 700 $checksum
            check $shell $root 'io.checksum.private-marker' 42 'checksum' ''
            for event in [null '' 'unrelated.private-marker' 'CHECKSUM' 'IO'] {
                check $shell $root $event 0 '' ''
            }
            rm $io $checksum
        }
        rm -r $root
    } catch {|err|
        rm -rf $root
        error make {msg: $err.rendered}
    }
    print 'PASS: router cases under sh, dash and bash'
}
