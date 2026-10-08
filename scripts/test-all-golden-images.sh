#!/bin/sh
# Legacy QEMU opens existing golden images writable and scrubs testpool without disk provenance.
printf '%s\n' 'HOLD (78): test-all-golden-images requires disposable off-NAS image copies.' >&2
exit 78
