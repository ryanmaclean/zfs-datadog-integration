# Next.js Telemetry Controls

We keep Next.js telemetry disabled across every environment. Key touchpoints:

1. **Global CLI preference** – run `npx next telemetry disable` (already executed on shared VMs) so the default is "opt-out" for every Next.js command.
2. **Environment variable** – export `NEXT_TELEMETRY_DISABLED=1` in every context.
   - Docker: `infrastructure/docker/next.env` or `ENV NEXT_TELEMETRY_DISABLED=1` in Dockerfiles.
   - Kubernetes: patch manifests with `infrastructure/kubernetes/nextjs-telemetry-patch.yaml` (or mirror the `env` block in Helm charts).
   - VM scripts: the repository's automation (`scripts/enhanced-e2e-test.sh`, `scripts/e2e-test.sh`, `scripts/install.sh`) now export the flag before invoking workloads.
3. **Package scripts** – set `NEXT_TELEMETRY_DISABLED=1` in `package.json` commands when adding Next.js projects to this repo.

If telemetry ever reappears, re-run the CLI disable command and audit your environment definitions for the env var.
