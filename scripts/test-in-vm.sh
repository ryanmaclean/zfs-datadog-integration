#!/usr/bin/env bash
# bash-required: pipefail
# Agent-local Lima integration is intentionally unavailable until a reviewed
# packaged Agent and an off-i9 disposable guest are bound to this source tree.
set -euo pipefail

printf '%s\n' \
  'HOLD: no licensed, exact-version packaged Datadog Agent is admitted for this VM.' \
  'The former HTTP mock and post-install ZED config overwrite are retired.' \
  'See AGENT-LOCAL-VM-FIXTURE.md for the required disposable-guest gate.' >&2
exit 78
