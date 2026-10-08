#!/bin/sh
# Legacy wrapper installs tools and builds golden images before reaching a held ZFS test.
printf '%s\n' 'HOLD (78): quick-start-parallel requires a verified disposable off-NAS build and test route.' >&2
exit 78
