#!/usr/bin/env bash
# Do not report green integration from a direct HTTP mock, a successful UDP
# write, or an unreviewed post-install replacement of sealed ZED config.
set -euo pipefail

printf '%s\n' \
  'HOLD: comprehensive Agent-local validation has no admitted packaged Agent fixture.' \
  'The former direct-HTTP mock, retry assertions, and sealed-config overwrite are retired.' \
  'Agent receive/forward and matched Datadog event plus metric readback remain required.' \
  'See AGENT-LOCAL-VM-FIXTURE.md.' >&2
exit 78
