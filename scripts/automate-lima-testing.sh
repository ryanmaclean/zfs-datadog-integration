#!/bin/sh
# Legacy named Lima guests are modified and testpool is force-created and scrubbed without ownership proof.
printf '%s\n' 'HOLD (78): automate-lima-testing requires a verified disposable off-NAS guest and disk.' >&2
exit 78
