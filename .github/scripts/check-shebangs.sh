#!/bin/sh
# Shebang policy, enforced in CI for every shell script in the repository
# (the set listed by .github/scripts/shell-scripts.sh):
#
#   #!/bin/sh            The default. ShellCheck then checks the file as POSIX
#                        sh and fails on any bashism, so the zedlets, library,
#                        config and installers stay runnable by ZED under
#                        FreeBSD/TrueNAS/illumos /bin/sh.
#
#   #!/usr/bin/env bash  Only where bash is genuinely needed. Line 2 must be
#                        "# bash-required: <the bash features it uses>", and
#                        the script must really use bash: if ShellCheck finds
#                        no bash-only construct when the file is checked as
#                        POSIX sh, it must be converted to #!/bin/sh instead.
#
# Any other shebang (#!/bin/bash, #!/usr/bin/env sh, zsh, ...) fails.
set -eu
cd "$(git rev-parse --show-toplevel)"

list=$(mktemp)
trap 'rm -f "$list"' EXIT
.github/scripts/shell-scripts.sh > "$list"

fail=0
count=0
while IFS= read -r f; do
    count=$((count + 1))
    first=$(head -n 1 "$f")
    case "$first" in
        '#!/bin/sh')
            printf '  ok    %s (POSIX sh)\n' "$f"
            ;;
        '#!/usr/bin/env bash')
            second=$(sed -n 2p "$f")
            case "$second" in
                '# bash-required: '?*) ;;
                *)
                    printf '  FAIL  %s: bash script without "# bash-required: <reason>" on line 2\n' "$f"
                    fail=1
                    continue
                    ;;
            esac
            if ! shellcheck --shell=sh --format=gcc "$f" 2>/dev/null | grep -q '\[SC3[0-9]*\]$'; then
                printf '  FAIL  %s: uses no bash-only features; convert it to #!/bin/sh\n' "$f"
                fail=1
                continue
            fi
            printf '  ok    %s (bash: %s)\n' "$f" "${second#\# bash-required: }"
            ;;
        *)
            printf '  FAIL  %s: shebang "%s" must be #!/bin/sh or #!/usr/bin/env bash\n' "$f" "$first"
            fail=1
            ;;
    esac
done < "$list"

if [ "$count" -eq 0 ]; then
    printf 'No shell scripts found; refusing to pass vacuously\n'
    exit 1
fi
if [ "$fail" -ne 0 ]; then
    printf 'Shebang policy check failed (see above)\n'
    exit 1
fi
printf 'Shebang policy OK for %d shell scripts\n' "$count"
