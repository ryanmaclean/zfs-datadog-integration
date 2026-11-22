#!/bin/sh
# Source-tarball regression: git archive (and so GitHub's tarball and zip
# downloads) must carry the integration and not the unrelated trees marked
# export-ignore in .gitattributes.
#
# The repository also holds an editor extension with its node_modules, VM and
# kernel build configs and session logs. Together they made the tarball about
# 80 MB, too heavy for the small hosts the installer targets. History is not
# touched: a plain clone still has everything.
#
# Usage: .github/scripts/test-export-archive.sh [max-bytes]
#   max-bytes is the uncompressed tar size limit (default 5242880).
set -eu
cd "$(git rev-parse --show-toplevel)"

max=${1:-5242880}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git archive --format=tar HEAD > "$work/export.tar"
tar -tf "$work/export.tar" > "$work/list"
fail=0

# Everything install.sh needs, plus the docs and the tests that guard it.
for required in scripts/install.sh scripts/uninstall.sh scripts/payload.sha256 \
    scripts/zfs-datadog-lib.sh scripts/config.sh scripts/config.sh.example \
    INSTALL.md README.md .gitattributes .github/scripts/test-zedlet-payloads.sh \
    .github/tests/zedlet-payloads.golden; do
    if ! grep -Fx -e "$required" "$work/list" > /dev/null; then
        printf 'FAIL  export lacks %s\n' "$required" >&2
        fail=1
    fi
done

# Every shipped payload name in the manifest must be in the export.
while read -r _ name; do
    if ! grep -Fx -e "scripts/$name" "$work/list" > /dev/null; then
        printf 'FAIL  export lacks payload scripts/%s\n' "$name" >&2
        fail=1
    fi
done < scripts/payload.sha256

# Trees that must stay out.
for pattern in node_modules/ '^code-app-ml-extension/' '^tauri-ios-example/' \
    '^macos-vm/' '^kernels/' '\.vsix$' '\.log$'; do
    if grep -E -e "$pattern" "$work/list" > "$work/hits"; then
        printf 'FAIL  export still contains %s, for example %s\n' "$pattern" "$(head -n 1 "$work/hits")" >&2
        fail=1
    fi
done

size=$(wc -c < "$work/export.tar")
size=${size##* }
if [ "$size" -gt "$max" ]; then
    printf 'FAIL  export is %s bytes, limit %s\n' "$size" "$max" >&2
    fail=1
fi
if [ "$fail" -eq 0 ]; then
    printf 'ok    export is %s bytes (limit %s), %s files\n' "$size" "$max" "$(wc -l < "$work/list" | tr -d ' ')"
fi
exit "$fail"
