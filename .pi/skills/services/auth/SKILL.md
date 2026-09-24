---
name: pi-auth-service
description: Use when designing, changing, or reviewing authentication/authorization/account services - login, registration, password reset, MFA/passkeys, sessions, OAuth2/OIDC tokens (incl. OpenIddict), external identity providers, key rotation, email change, account deletion. Owns the defect checks; `auth-core` owns the design workflow.
---
# Auth Service Blueprint

Owns:
- registration and account lifecycle (email confirmation, change, deletion)
- login/logout, sessions or token lifecycle, step-up/re-authentication
- password reset and account recovery, MFA/passkeys where required
- roles/permissions or integration with authorization policy
- security/audit events

Principles:
- Prefer ASP.NET Core Identity / established OAuth2/OIDC components over custom security protocols.
- Separate authentication and authorization; keep authorization decisions on the server.
- Never log tokens, codes, passwords, or cookies. Make account/security changes auditable.

## Checks that catch real defects

Each item names the failure it prevents. Verify against the live code and installed versions
(read the library's source or docs; do not rely on memory of framework behavior).

1. **Enumeration.** Register, login, and forgot-password give the same status, body, and roughly
   the same timing whether or not the account exists. Test: existing vs unknown address, compare.
   A framework's own duplicate-account error (ASP.NET Identity's `DuplicateUserName`/
   `DuplicateEmail`, code AND message text) is exactly this leak if passed through uncaught -
   register is easy to miss since login/forgot-password are the ones usually written carefully.
2. **Two throttles, different jobs.** A per-IP rate limit is cheap abuse control but attackers
   rotate IPs; per-account lockout is what stops guessing. Second-factor and recovery-code
   failures must count toward lockout. Lockout can be used to lock a victim out - allow recovery
   during lockout and prefer time-boxed lockout.
3. **Every credential change ends sessions.** Password change/reset, 2FA change, email change,
   passkey removal: rotate the security stamp AND revoke server-side session records AND refresh
   tokens. A feature written before the session list existed silently left other browsers' cookies
   valid. Test: two sign-ins, change in one, the other's cookie is rejected.
4. **Trust an external identity only when verified.** Map the provider's verified-email flag
   (Google's `email_verified` is not mapped by the stock ASP.NET handler) and treat missing as
   false. After the first link use the provider subject (`sub`), not the email. Never link into an
   *unconfirmed* local account as-is: a squatter can pre-register the victim's address with a
   known password (account pre-hijacking). Take the row over (remove password, confirm address,
   rotate stamp) or refuse. The FIRST link is decided by an email match alone, so if the local
   account has 2FA enabled send the caller through the normal second-factor challenge instead of
   signing in; later sign-ins with an already-linked provider may skip it.
5. **Step-up must be readable where it is enforced.** A claim that exists only in OIDC access
   tokens cannot guard cookie-authenticated endpoints; those need password/2FA re-entry. Register
   the policy in every host that uses the attribute (an unregistered policy returns 500, not 403).
   Test both the denied and the elevated path.
6. **Tokens.** Authorization Code + PKCE for public clients, exact redirect-URI matching,
   audience-restricted short-lived access tokens, refresh-token rotation or sender-constraint for
   public clients (RFC 9700 §2.1, 2.1.1, 2.2.2, 2.3). Validate issuer, audience, signature, lifetime,
   and allowed algorithms; fail closed.
7. **Key rotation.**
   - Retention per key purpose: a signing key needs only the access-token lifetime plus JWKS-cache
     slack; an *encryption* key protects refresh tokens and must outlive the longest of them.
   - Count retention from when a key stops being current, not from its creation (otherwise a
     30-day-old key is retired the moment it is superseded).
   - Do not assume which key signs new tokens; assert the new `kid` in a test.
   - If options are cached, invalidate every cache that derived key material (token server AND
     validation) or new tokens are issued but rejected.
   - Prove it: token issued before rotation validates after; token after carries a new `kid`; no
     restart.
   - Serialize rotation across instances (a rolling deploy overlaps old and new): take a
     transaction-scoped database lock and re-check "is it due" AFTER acquiring it, or every waiter
     mints its own key. Test with several concurrent callers; remove the lock and watch it fail.
   - Private keys in the database are secrets. Encrypt them at rest with a master key held outside
     the database (AES-256-GCM, with purpose + key id as associated data so a ciphertext cannot be
     moved to another row), require it in Production, encrypt legacy plaintext rows on startup, and
     plan master-key rotation. A database-only leak must not yield token-forging keys.
   - Cookies and reset/confirmation tokens depend on the ASP.NET Data Protection key ring: persist
     and share it (all instances, every redeploy) or every deploy signs users out and kills pending
     links.
8. **Passwords.** Follow NIST SP 800-63B: minimum length and a blocklist of breached/common
   passwords; no composition rules; no forced periodic change. The HIBP range API is k-anonymous
   (send only the first 5 hex chars of the SHA-1; send `Add-Padding: true`). Decide, document, and
   test what happens when the checker is unreachable (fail open with a short timeout, or closed).
9. **Passkeys/WebAuthn.** Relying-party ID and origins come from configuration of the public
   issuer, never from the request. Challenges are single-use and short-lived. Discoverable
   credentials enable username-less login; a passkey login that skips TOTP is a deliberate,
   documented choice.
10. **Email change and account deletion.** Require re-authentication, confirm at the new address,
    notify the old one, bind tokens to the security stamp and make them single-use. Deletion ends
    all sessions/tokens and publishes an event for downstream owners of derived data.
11. **Recovery/admin paths obey the same rules** as the main path (sessions ended, audit event
    written, notification sent).

## Verification

Use `.pi/laws/proof-obligations.md` (credential change, external linking, token/key lifecycle,
step-up). Require negative tests - the attacker, the wrong client, the expired/tampered token,
the unverified email - alongside the happy path, and a real HTTP flow where runnable. High-risk:
use `pi-independent-verifier`.

References (primary): NIST SP 800-63B; OWASP Authentication, Forgot Password and Session
Management cheat sheets; RFC 9700 (OAuth 2.0 Security BCP); OpenID Connect Core; W3C WebAuthn;
Microsoft Research "Pre-hijacking Attacks on Web User Accounts" (USENIX Security 2022).
