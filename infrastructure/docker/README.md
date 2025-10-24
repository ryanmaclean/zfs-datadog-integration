# Docker Telemetry Controls

To keep Next.js telemetry disabled inside every image and container, add the shared env file:

```dockerfile
# Dockerfile
ENV NEXT_TELEMETRY_DISABLED=1
```

or mount/include `next.env`:

```yaml
# docker-compose.yml
services:
  web:
    env_file:
      - ./infrastructure/docker/next.env
```

The repository's CI and local build scripts should also export `NEXT_TELEMETRY_DISABLED=1` for consistency.
