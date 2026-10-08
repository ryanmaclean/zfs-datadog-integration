#!/bin/sh
# Legacy named Lima guests are modified and testpool is scrubbed or force-created without ownership proof.
printf '%s\n' 'HOLD (78): automate-lima-fixed requires a verified disposable off-NAS guest and disk.' >&2
exit 78
