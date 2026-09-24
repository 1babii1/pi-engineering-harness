---
name: pi-docker
description: Use for Dockerfiles, Compose, container builds, images, and local/prod container practices.
---
# Docker

- Use multi-stage builds where useful.
- Keep runtime images small and non-root when practical.
- Do not bake secrets into images.
- Use explicit health checks only when they reflect meaningful process health.
- Keep development conveniences separate from production images.
- Pin important base/runtime versions intentionally.
- Prefer reproducible builds.
- Use Compose for simple local orchestration when it is sufficient.
