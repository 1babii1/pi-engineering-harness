---
name: pi-payment-service
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

State changes must be atomic and duplicate-safe:
- Move state with a conditional write (`UPDATE ... WHERE status = 'processing'`, or a version
  check), never read-then-write, so two workers or two webhook deliveries cannot both win.
- Record each provider event id under a unique constraint; a duplicate delivery then becomes a
  no-op instead of a second charge, refund, or email.
