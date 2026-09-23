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
- Treat a third party's assertion (a provider's email, a webhook field) as untrusted until its
  own "verified"/signature flag is checked; a missing flag means not verified.
- Credential changes must end the sessions and tokens they invalidate.
- For account/auth services load `services/auth` for concrete checks.
