#!/bin/sh
# Legacy named Lima guests are deleted and testpool is force-created and scrubbed without ownership proof.
printf '%s\n' 'HOLD (78): all-distros-test requires a verified disposable off-NAS guest and disk.' >&2
exit 78
