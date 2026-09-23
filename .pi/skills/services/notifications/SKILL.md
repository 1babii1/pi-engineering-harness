---
name: notification-service
description: Use when designing email, SMS, push, in-app notification systems.
---
# Notification Service Blueprint

Typical flow:
producer -> queue/event -> notification worker -> provider

Owns:
- channel routing
- templates/localization
- user notification preferences
- scheduling/quiet hours when required
- consent/opt-out per channel (unsubscribe link, STOP handling) - required for marketing mail/SMS
  in most jurisdictions, and worth honoring for transactional notifications where the channel
  allows it
- provider adapters
- delivery state and attempts

Reliability:
- idempotency key/message id
- retries with backoff
- DLQ / poison-message handling
- provider rate limits
- optional provider failover

Observe:
- accepted/sent/failed counts
- processing latency
- provider latency/error rate
- queue depth
- retry/DLQ counts
