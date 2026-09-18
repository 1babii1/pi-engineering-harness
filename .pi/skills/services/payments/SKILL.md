---
name: payment-service
description: Use when designing payment flows, payment providers, webhooks, refunds, and financial state transitions.
---
# Payment Service Blueprint

Model payment flow as explicit states, e.g. created -> processing -> succeeded/failed/cancelled/refunded.

Always consider:
- idempotency keys
- authoritative server-side amount/currency
- webhook signature verification
- duplicate/out-of-order webhooks
- audit trail
- reconciliation with provider records
- transactional outbox for integration events when needed
- money representation using integer minor units or an appropriate fixed decimal model

Never trust prices or payment status supplied by the frontend.
