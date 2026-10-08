#!/bin/sh
# Legacy named Lima guest force-creates testpool without disk provenance.
printf '%s\n' 'HOLD (78): run-actual-zfs-build requires a verified disposable off-NAS guest and disk.' >&2
exit 78
