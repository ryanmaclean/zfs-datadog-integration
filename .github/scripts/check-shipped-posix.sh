#!/bin/sh
# The files scripts/install.sh puts on a host run under the host's /bin/sh
# (FreeBSD/TrueNAS ash, Debian dash, illumos ksh). They must be POSIX sh with
# no exceptions: line 1 exactly "#!/bin/sh", and no "# bash-required:" escape
# hatch, even though check-shebangs.sh allows that for developer tooling.
#
# The shipped set is read from install.sh (LIB, ZEDLETS, HANDLERS) plus the
# installer, uninstaller, validator and config files, so a new zedlet is
# covered as soon as the installer ships it.
set -eu
cd "$(git rev-parse --show-toplevel)"

lib=$(sed -n "s/^LIB='\\(.*\\)'\$/\\1/p" scripts/install.sh)
zedlets=$(sed -n "/^ZEDLETS='/,/'\$/p" scripts/install.sh | tr -d "'" | sed 's/^ZEDLETS=//')
handlers=$(sed -n "s/^HANDLERS='\\(.*\\)'\$/\\1/p" scripts/install.sh)
if [ -z "$lib" ] || [ -z "$zedlets" ] || [ -z "$handlers" ]; then
    echo "Could not read LIB/ZEDLETS/HANDLERS from scripts/install.sh" >&2
    exit 1
fi

fail=0
count=0
for f in $lib $zedlets $handlers install.sh uninstall.sh validate-config.sh config.sh config.sh.example; do
    path="scripts/$f"
    count=$((count + 1))
    before=$fail
    if [ ! -f "$path" ]; then
        printf '  FAIL  %s: shipped by install.sh but missing\n' "$path"
        fail=1
        continue
    fi
    if [ "$(head -n 1 "$path")" != '#!/bin/sh' ]; then
        printf '  FAIL  %s: shipped file must start with #!/bin/sh\n' "$path"
        fail=1
        continue
    fi
    if grep -q '^# bash-required:' "$path"; then
        printf '  FAIL  %s: shipped file may not declare bash-required\n' "$path"
        fail=1
        continue
    fi
    if command -v dash > /dev/null 2>&1 && ! dash -n "$path"; then
        printf '  FAIL  %s: does not parse under dash\n' "$path"
        fail=1
    fi
    if command -v bash > /dev/null 2>&1 && ! bash --posix -n "$path"; then
        printf '  FAIL  %s: does not parse under bash --posix\n' "$path"
        fail=1
    fi
    [ "$fail" -eq "$before" ] && printf '  ok    %s\n' "$path"
done

if [ "$fail" -ne 0 ]; then
    echo "Shipped-script POSIX check failed"
    exit 1
fi
printf 'All %d shipped scripts are POSIX sh\n' "$count"
