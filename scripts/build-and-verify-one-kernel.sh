#!/bin/sh
# Legacy named-guest kernel/ZFS test; guest and disk provenance are not established.
printf '%s\n' 'HOLD (78): build-and-verify-one-kernel lacks verified disposable Lima guest and ZFS disk provenance.' >&2
exit 78
