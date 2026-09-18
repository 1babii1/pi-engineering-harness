---
name: kubernetes-audit
description: Read-only audit for Kubernetes manifests, Helm and Kustomize covering security, reliability, resources, networking and deployment safety.
---
# Kubernetes Audit

Audit only. Do not modify manifests unless explicitly asked.

## Security
Check when applicable:
- `runAsNonRoot`;
- `allowPrivilegeEscalation: false`;
- read-only root filesystem;
- dropped Linux capabilities;
- non-privileged containers;
- appropriate seccomp profile;
- ServiceAccount scope and token automount;
- RBAC least privilege;
- Secrets vs ConfigMaps;
- NetworkPolicies;
- Pod Security Standards alignment.

## Reliability
Check:
- startup/readiness/liveness probes with correct semantics;
- graceful shutdown and termination grace period;
- replica count relative to availability requirement;
- rolling update strategy;
- PodDisruptionBudget when availability requires it;
- topology spread / anti-affinity when failure-domain concentration matters;
- HPA only where scaling signals make sense.

## Resources
Check CPU/memory requests and limits. Do not invent values without workload evidence.

## Tooling
When available, use static evidence from tools such as KubeLinter and Trivy. Treat tool output as evidence, then validate context before reporting.

## Findings
Include severity, confidence, manifest/resource, evidence, impact and recommendation.
