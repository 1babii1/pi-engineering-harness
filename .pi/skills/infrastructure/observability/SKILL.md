---
name: observability
description: Use for logs, metrics, traces, OpenTelemetry, SLI/SLO, dashboards, and production diagnosis.
---
# Observability

Instrument three signals:
- Logs
- Metrics
- Distributed traces

Prefer OpenTelemetry-compatible instrumentation and semantic conventions.

Track the four golden signals where relevant:
- latency
- traffic
- errors
- saturation

For each production service identify:
- critical operations
- useful structured log context
- request/job/message duration
- success/error counts
- queue depth or resource saturation
- dependency latency/errors

Define SLI/SLO from user-visible reliability when the service is important enough. Do not invent arbitrary SLO numbers.

Observability should help answer: what failed, where, when, for whom, and why?
