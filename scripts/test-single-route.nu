#!/usr/bin/env nu
# Source-only ZED selector fixture. Run from any directory with the repo path.
def selected [files: list<string>, event_class: string] {
    $files | where {|name| $name == 'all-datadog.sh' or ($name | str starts-with $"($event_class)-") }
}

def require_one [profile: string, files: list<string>, event_class: string] {
    let matches = (selected $files $event_class)
    if (($matches | length) != 1) {
        error make {msg: $"($profile): ($event_class) selected ($matches | length) routes: ($matches | str join ', ')"}
    }
}

def main [repo_root: string] {
    let repo = ($repo_root | path expand)
    let install = (open --raw $"($repo)/scripts/install.sh")
    let pinned_manifest = '77e67d33c1716d4760e5b8c67bdc91ef684937624e086498311d9dd4f72e7116'
    let pinned_installer = 'e3f8009df25e541b08fca0237f0f61e881bcb99e38723cc229b3df8a54fdbef3'
    let manifest = (open --raw $"($repo)/scripts/payload.sha256")
    if (($manifest | hash sha256) != $pinned_manifest) {
        error make {msg: 'reviewed payload manifest digest changed'}
    }
    if (($install | hash sha256) != $pinned_installer) {
        error make {msg: 'reviewed installer digest changed'}
    }
    let manifest_lines = ($manifest | lines | where {|line| $line != ''})
    if (($manifest_lines | length) != 17) {
        error make {msg: 'payload manifest must enumerate 17 files'}
    }
    for line in $manifest_lines {
        let parts = ($line | split row ' ')
        if (($parts | length) != 2) {
            error make {msg: $"malformed payload line: ($line)"}
        }
        let actual = (open --raw $"($repo)/scripts/($parts.1)" | hash sha256)
        if ($actual != $parts.0) {
            error make {msg: $"payload differs from manifest: ($parts.1)"}
        }
    }
    let fresh = ($install | split row "ZEDLETS='" | get 1 | split row "'" | first | lines | where {|line| $line != ''})

    for event_class in ['ereport.fs.zfs.checksum', 'ereport.fs.zfs.io'] {
        require_one 'fresh guarded install' $fresh $event_class
    }

    # An existing all-event router would make two dispatches. The guarded
    # installer must reject that source state before stopping ZED or copying.
    let existing = ($fresh | append 'all-datadog.sh')
    if (((selected $existing 'ereport.fs.zfs.checksum') | length) != 2) {
        error make {msg: 'legacy duplicate-route fixture no longer reproduces'}
    }
    if not ($install | str contains "OLD_ROUTES='all-datadog.sh checksum-error.sh io-error.sh'") {
        error make {msg: 'installer lost the existing-route preflight block'}
    }
    if not ($install | str contains 'Existing integration path requires reviewed migration') {
        error make {msg: 'installer no longer fails closed on existing routes'}
    }

    for distro in ['ubuntu', 'debian', 'rocky', 'fedora', 'arch'] {
        let packer = (open --raw $"($repo)/packer/packer-($distro)-zfs.pkr.hcl")
        let uploaded = ($packer | parse -r 'scripts/(?P<name>[A-Za-z0-9_.-]+[.]sh)' | get name)
        for required in ($fresh | append '.checksum-error.sh' | append '.io-error.sh') {
            let source_name = ($required | str trim --left --char '.')
            if not ($source_name in $uploaded) {
                error make {msg: $"($distro) Packer upload lacks ($source_name)"}
            }
        }
        if ('all-datadog.sh' in $uploaded) {
            error make {msg: $"($distro) Packer still uploads the all-event route"}
        }
        if not ($packer | str contains $"ZFS_DD_EXPECTED_MANIFEST_SHA=($pinned_manifest) sh /root/zfs-datadog-src/install.sh") {
            error make {msg: $"($distro) Packer bypasses guarded activation"}
        }
        if not ($packer | str contains $pinned_installer) or ($packer | str contains '/tmp/*.sh') {
            error make {msg: $"($distro) Packer lacks sealed installer or still uses a wildcard upload"}
        }
        for event_class in ['ereport.fs.zfs.checksum', 'ereport.fs.zfs.io'] {
            require_one $"($distro) Packer guarded install" $fresh $event_class
        }
    }

    let lima = (open --raw $"($repo)/scripts/automate-lima-complete.sh")
    let lima_payload = ($lima | split row 'payload=(' | get 1 | split row ')' | first | parse -r '(?P<name>[A-Za-z0-9_.-]+[.]sh)' | get name)
    for required in ($fresh | append 'checksum-error.sh' | append 'io-error.sh' | append 'install.sh') {
        if not ($required in $lima_payload) {
            error make {msg: $"Lima upload lacks ($required)"}
        }
    }
    if ('all-datadog.sh' in $lima_payload) {
        error make {msg: 'Lima still uploads the all-event route'}
    }
    if not ($lima | str contains $"ZFS_DD_EXPECTED_MANIFEST_SHA=($pinned_manifest) sh /root/zfs-datadog-src/install.sh") {
        error make {msg: 'Lima bypasses guarded activation'}
    }
    if not ($lima | str contains $pinned_installer) or ($lima | str contains '/tmp/*.sh') {
        error make {msg: 'Lima lacks sealed installer or still uses a wildcard upload'}
    }
    for event_class in ['ereport.fs.zfs.checksum', 'ereport.fs.zfs.io'] {
        require_one 'Lima guarded install' $fresh $event_class
    }

    print 'PASS: fresh, five Packer, and Lima profiles select one exact route per ereport; existing all-route profile is blocked'
}
