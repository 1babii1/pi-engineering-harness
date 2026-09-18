---
name: security-audit
description: Read-only application security audit guided by OWASP-style trust-boundary analysis and concrete exploitability.
---
# Security Audit

Audit only. Do not change code unless explicitly asked.

## Trace trust boundaries
For each external input identify:
- source;
- validation;
- authentication context;
- authorization decision;
- processing;
- persistence or external sink.

## Review areas
- authentication and account recovery;
- authorization and object ownership;
- injection and unsafe deserialization;
- SSRF and outbound requests;
- file uploads;
- secrets and credentials;
- token/session handling;
- CORS/CSRF where applicable;
- rate limiting on abuse-sensitive operations;
- sensitive logging and error leakage;
- dependency and supply-chain risks;
- webhook signature verification;
- encryption/crypto misuse.

## Rules
- Never invent an exploit path without evidence.
- Separate confirmed vulnerability from suspicious pattern.
- Prefer established framework security mechanisms over custom crypto/auth.

## Finding format
Severity: Critical / High / Medium / Low
Confidence: High / Medium / Low
Evidence: concrete file/config/flow
Impact: realistic attacker outcome
Fix: smallest effective mitigation
