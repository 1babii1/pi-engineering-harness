Verify the provider's HMAC signature header against the raw request body before parsing anything -
an unsigned or wrongly-signed request is rejected with 400 before it is trusted at all. Store the
provider's event id with a unique constraint and treat a duplicate id as an idempotent no-op (return
200 without reprocessing), since providers redeliver webhooks. Read the charge amount/status only
from the verified payload, never recompute it from anything else the caller could influence.
