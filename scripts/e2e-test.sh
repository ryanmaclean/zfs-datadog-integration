#!/bin/sh
# Legacy Lima/ZFS end-to-end test; guest and disk provenance are not established.
printf '%s\n' 'HOLD (78): e2e-test lacks verified disposable Lima guest and ZFS disk provenance.' >&2
exit 78
