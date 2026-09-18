---
name: security
description: Use for authentication, authorization, secrets, input boundaries, OWASP concerns, and security reviews.
---
# Security

- Prefer established platform/security libraries over custom cryptography or auth protocols.
- Separate authentication (who) from authorization (what they may do).
- Validate untrusted input at boundaries.
- Apply least privilege.
- Never log secrets, credentials, access tokens, refresh tokens, or sensitive personal data unnecessarily.
- Store secrets outside source control.
- Rate-limit abuse-prone endpoints such as login, registration, password reset, and code delivery.
- Verify webhook signatures and replay protections.
- Treat authorization checks as server-side responsibilities.
- Keep service/database credentials separate from end-user identities.
