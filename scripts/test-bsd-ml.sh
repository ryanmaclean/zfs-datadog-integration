#!/bin/sh
# Legacy ML test deleted a named Lima guest and mounted unverified /Volumes/tank3.
printf '%s\n' 'HOLD (78): test-bsd-ml lacks disposable guest ownership and off-NAS storage provenance.' >&2
exit 78
