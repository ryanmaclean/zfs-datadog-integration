#!/bin/sh
# List every tracked shell script in the repository, one path per line:
# all *.sh files plus extensionless files (e.g. scripts/config.sh.example)
# whose first line is a sh/bash/dash/ksh/zsh shebang. Used by CI so that
# ShellCheck, syntax and shebang checks all cover the same set of files.
set -eu
cd "$(git rev-parse --show-toplevel)"
git ls-files | while IFS= read -r f; do
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
done
