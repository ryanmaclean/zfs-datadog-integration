#!/bin/sh
# Do not install Lima on the laptop or advertise the retired integration path.
printf '%s\n' \
  'HOLD: no reviewed off-i9 disposable VM and packaged Agent-local fixture.' \
  'Lima is not installed and no VM is started by this entrypoint.' >&2
exit 78
