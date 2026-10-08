#!/bin/sh
# Legacy VM build path wrote images under unverified /Volumes/tank3 storage.
printf '%s\n' 'HOLD (78): actually-run-builds used unverified /Volumes/tank3; no disposable storage provenance.' >&2
exit 78
