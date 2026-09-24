---
name: pi-project-discovery
description: Use when onboarding to a repository, refreshing project context, or before a large cross-cutting change.
---
# Project Discovery

Goal: learn the repository quickly without reading everything.

## Workflow
1. Identify entry points and workspace files (`*.sln`, `*.csproj`, `package.json`, Docker/Kubernetes files).
2. Map only the major boundaries: frontend, backend, data, infrastructure, tests.
3. Discover the real build/test/lint/run commands from project files and CI.
4. Find canonical examples of common work: endpoint, DB access, test, component, query hook, deployment manifest.
5. Record architectural decisions only when supported by evidence.
6. Save only material context that would be expensive or error-prone to rediscover.

## Output
Maintain `.pi/project/`:
- `overview.md` — stack, entry points, major directories.
- `architecture.md` — boundaries and important dependencies.
- `commands.md` — exact verified commands.
- `conventions.md` — project-specific conventions not enforced by tools.
- `canonical-examples.md` — paths to preferred examples and why they are canonical.

## Evidence and confidence
For non-obvious claims include:
- Evidence: file/path/config that supports the claim.
- Confidence: High / Medium / Low.

Do not turn guesses into facts.

## Context budget
- Prefer search -> targeted read.
- Do not document formatter/linter defaults.
- Do not copy large source files into context.
- Prefer file paths over pasted code.
- Keep each project-context file concise; split only when necessary.
