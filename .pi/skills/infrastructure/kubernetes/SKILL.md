---
name: pi-kubernetes
description: Use when designing or reviewing Kubernetes deployments and production container orchestration.
---
# Kubernetes

Use Kubernetes only when its operational benefits justify its complexity.

For production workloads consider:
- Deployment / StatefulSet as appropriate
- Service / ingress or gateway
- ConfigMap and Secret handling
- resource requests and limits
- startup, readiness, and liveness probes
- graceful shutdown
- rolling updates
- HPA when scaling signals exist
- PodDisruptionBudget for availability-sensitive workloads
- topology spread / anti-affinity across failure domains
- NetworkPolicy when network isolation matters

Probe meaning:
- startup: has the app finished starting?
- readiness: may it receive traffic now?
- liveness: is it stuck and should it be restarted?

Do not use liveness checks for temporary downstream dependency failures.
