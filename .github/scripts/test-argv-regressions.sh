#!/bin/sh
# Dry-run regression test for argument handling in the VM helper scripts.
#
# Runs the scripts against stub commands that record the exact argv they
# receive (no VM, network or disk work happens), then checks that:
#   1. QEMU gets no empty argument and no bundled "-opt value" word
#      (qemu-freebsd.sh, qemu-netbsd.sh, qemu-truenas-scale.sh), and that
#      "-accel" is followed by its own "hvf" argument;
#   2. ssh/scp get each "-o Option=value" as separate arguments
#      (test-truenas-core.sh, test-truenas-scale.sh);
#   3. colour variables hold real ESC bytes, so the converted printf '%s'
#      calls in uninstall.sh / validate-config.sh emit colours, not literal
#      "\033[...m" text; and no script assigns a literal \033 sequence.
set -eu
cd "$(git rev-parse --show-toplevel)"
REPO=$(pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
STUBS="$WORK/stubs"
LOG="$WORK/argv.log"
mkdir -p "$STUBS"
: > "$LOG"

# Recording stub: one line per call, the command name followed by each
# argument, separated by the ASCII unit separator (0x1f), so empty
# arguments and embedded spaces stay visible.
cat > "$STUBS/_record" <<'STUB'
#!/bin/sh
name=$(basename "$0")
{
    printf '%s' "$name"
    for a in "$@"; do printf '\037%s' "$a"; done
    printf '\n'
} >> "$ARGV_LOG"
case "$name" in
    ssh|scp|jq) cat > /dev/null ;;
esac
[ "$name" = jq ] && echo 1
exit 0
STUB
chmod +x "$STUBS/_record"
for c in qemu-system-x86_64 qemu-system-aarch64 qemu-img curl wget xz gunzip \
         mkisofs genisoimage hdiutil brew ssh scp jq sleep nc; do
    ln -s _record "$STUBS/$c"
done
cat > "$STUBS/uname" <<'STUB'
#!/bin/sh
if [ "${1:-}" = "-m" ]; then echo "$FAKE_ARCH"; else exec /usr/bin/env -i PATH=/usr/bin:/bin uname "$@"; fi
STUB
chmod +x "$STUBS/uname"

fail=0
bad() { printf '  FAIL  %s\n' "$*"; fail=1; }
ok() { printf '  ok    %s\n' "$*"; }

# Fail on empty or bundled ("-opt value") arguments for the given commands.
check_argv() {
    label=$1; shift
    for cmd in "$@"; do
        if ! grep -q "^$cmd" "$LOG"; then
            bad "$label: $cmd was never called"
            continue
        fi
    done
    problems=$(awk -F '\037' -v cmds="$*" '
        BEGIN { n = split(cmds, c, " "); for (i = 1; i <= n; i++) want[c[i]] = 1 }
        ($1 in want) || ($1 ~ /^qemu-system-/ && want["qemu-system-*"]) {
            for (i = 2; i <= NF; i++) {
                if ($i == "") printf "%s: empty argument at position %d\n", $1, i - 1
                else if ($i ~ /^-/ && $i ~ /[ \t]/) printf "%s: bundled argument [%s]\n", $1, $i
            }
        }' "$LOG")
    if [ -n "$problems" ]; then
        bad "$label: $problems"
    else
        ok "$label: argv clean"
    fi
}

has_pair() { # has_pair CMD_REGEX OPT VALUE: OPT is immediately followed by VALUE
    awk -F '\037' -v re="$1" -v o="$2" -v v="$3" '
        $1 ~ re { for (i = 2; i < NF; i++) if ($i == o && $(i + 1) == v) found = 1 }
        END { exit !found }' "$LOG"
}

run_copy() { # run_copy SCRIPT ARCH [files to pre-create...]
    script=$1; arch=$2; shift 2
    dir="$WORK/run-$(basename "$script" .sh)-$arch"
    mkdir -p "$dir"
    cp "$REPO/$script" "$dir/"
    for f in "$@"; do : > "$dir/$f"; done
    : > "$LOG"
    (cd "$dir" && PATH="$STUBS:$PATH" ARGV_LOG="$LOG" FAKE_ARCH="$arch" \
        bash "./$(basename "$script")" < /dev/null > "$dir/out.txt" 2>&1) ||
        bad "$script ($arch) exited non-zero: $(tail -n 3 "$dir/out.txt")"
}

echo "1. QEMU argv"
run_copy scripts/qemu-freebsd.sh arm64 freebsd-amd64.qcow2
check_argv "qemu-freebsd.sh" "qemu-system-*"
run_copy scripts/qemu-netbsd.sh arm64 netbsd-10.0-amd64.qcow2
check_argv "qemu-netbsd.sh" "qemu-system-*"
for arch in arm64 x86_64; do
    run_copy scripts/qemu-truenas-scale.sh "$arch" truenas-scale.iso truenas-scale-disk.qcow2
    check_argv "qemu-truenas-scale.sh ($arch)" "qemu-system-*"
    if has_pair '^qemu-system-' -accel hvf; then
        ok "qemu-truenas-scale.sh ($arch): -accel hvf passed as two arguments"
    else
        bad "qemu-truenas-scale.sh ($arch): -accel not followed by a separate hvf argument"
    fi
done

echo "2. ssh/scp argv"
for t in core scale; do
    dir="$WORK/run-truenas-$t"
    mkdir -p "$dir"
    cp "$REPO/scripts/test-truenas-$t.sh" "$dir/"
    printf '#!/bin/sh\nexit 0\n' > "$dir/wait-for-ssh.sh"
    chmod +x "$dir/wait-for-ssh.sh"
    : > "$LOG"
    (cd "$dir" && PATH="$STUBS:$PATH" ARGV_LOG="$LOG" FAKE_ARCH=x86_64 \
        sh "./test-truenas-$t.sh" < /dev/null > "$dir/out.txt" 2>&1) ||
        bad "test-truenas-$t.sh exited non-zero: $(tail -n 3 "$dir/out.txt")"
    check_argv "test-truenas-$t.sh" ssh scp
    for c in ssh scp; do
        if has_pair "^$c\$" -o StrictHostKeyChecking=no && has_pair "^$c\$" -o UserKnownHostsFile=/dev/null; then
            ok "test-truenas-$t.sh: $c gets each -o option separately"
        else
            bad "test-truenas-$t.sh: $c did not get separate -o options"
        fi
    done
done

echo "3. colour output"
esc=$(printf '\033')
check_colour() { # check_colour LABEL FILE
    if grep -q '\\033\[' "$2"; then
        bad "$1: printed a literal \\033 sequence"
    elif ! grep -q "$esc\[" "$2"; then
        bad "$1: no ANSI colour sequence in output"
    else
        ok "$1: real ESC bytes, no literal \\033"
    fi
}
sh scripts/uninstall.sh --no-such-option < /dev/null > "$WORK/uninstall.txt" 2>&1 || true
check_colour "uninstall.sh" "$WORK/uninstall.txt"
(PATH="$STUBS:$PATH" ARGV_LOG="$WORK/ignored.log" FAKE_ARCH=x86_64 \
    sh scripts/validate-config.sh < /dev/null > "$WORK/validate.txt" 2>&1) || true
check_colour "validate-config.sh" "$WORK/validate.txt"
script_list="$WORK/shell-scripts.txt"
.github/scripts/shell-scripts.sh > "$script_list"
literal=$(tr '\n' '\0' < "$script_list" |
    xargs -0 grep -nE "^[[:space:]]*(export |readonly |local )?[A-Za-z_][A-Za-z_0-9]*=[\"']\\\\(033|e|x1b)\[" || true)
if [ -n "$literal" ]; then
    bad "colour variables assigned literal escape text (use \$(printf '\\033[...m')):
$literal"
else
    ok "no script assigns a literal \\033 colour string"
fi

if [ "$fail" -ne 0 ]; then
    echo "argv/colour regression test FAILED"
    exit 1
fi
echo "argv/colour regression test passed"
