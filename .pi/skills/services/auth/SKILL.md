---
name: auth-service
description: Use when designing authentication/authorization/account services.
---
# Auth Service Blueprint

Owns:
- registration and account lifecycle
- email/phone verification
- login/logout/session or token lifecycle
- password reset
- MFA where required
- roles/permissions or integration with authorization policy
- security/audit events

Principles:
- Prefer ASP.NET Core Identity / established OAuth2/OIDC components over custom security protocols.
- Separate authentication and authorization.
- Rate-limit abuse-prone endpoints.
- Support lockout/throttling against credential attacks.
- Keep token/secret handling out of logs.
- Make account/security changes auditable.
- Keep authorization decisions on the server.
