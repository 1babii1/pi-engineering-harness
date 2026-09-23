Sending the email does not need to block the order request, so make it asynchronous.
Write the order and an outbox row in the same database transaction, then let a background worker
publish the event and send the email. This keeps DB state and event publication atomic without a
distributed transaction. Delivery is at-least-once, so the email handler must be idempotent
(store a sent-marker keyed by order id) and retries use a bounded backoff with a dead-letter table.
A plain in-process queue plus outbox table is enough; nothing more is needed at this scale.
