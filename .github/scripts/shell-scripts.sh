#!/bin/sh
# List every tracked shell script in the repository, one path per line.
# Reject Git-quoted paths first: the line-oriented CI consumers cannot safely
# represent names containing tabs/newlines (or other quoted bytes).
# all *.sh files plus extensionless files (e.g. scripts/config.sh.example)
# whose first line is a sh/bash/dash/ksh/zsh shebang. Used by CI so that
# ShellCheck, syntax and shebang checks all cover the same set of files.
set -eu
cd "$(git rev-parse --show-toplevel)"
tracked=$(mktemp)
trap 'rm -f "$tracked"' EXIT
git -c core.quotePath=true ls-files > "$tracked"
if LC_ALL=C grep -q '^"' "$tracked"; then
    printf '%s\n' 'Tracked path needs Git quoting; refusing incomplete shell-script checks' >&2
    exit 1
fi
while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in
        *.sh) printf '%s\n' "$f" ;;
        *)
            if head -n 1 "$f" 2>/dev/null |
                grep -Eq '^#![[:space:]]*[^[:space:]]*/(env[[:space:]]+)?(ba|da|k|z)?sh([[:space:]]|$)'; then
                printf '%s\n' "$f"
            fi
            ;;
    esac
done < "$tracked"
