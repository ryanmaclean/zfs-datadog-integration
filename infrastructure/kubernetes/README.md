# Kubernetes Telemetry Patch

Apply or merge the provided patch to every workload running Next.js:

```bash
kubectl patch deployment <name> --patch-file infrastructure/kubernetes/nextjs-telemetry-patch.yaml --type merge
```

Or include the `env` block directly in Helm charts/manifest templates to guarantee `NEXT_TELEMETRY_DISABLED=1` in all pods.
