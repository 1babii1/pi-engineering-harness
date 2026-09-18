# Production Service Checklist

Use selectively based on service criticality.

- Clear ownership and responsibility boundary
- Stable API/event contracts
- Input validation
- Authentication/authorization where required
- Secrets management
- Database constraints and indexes
- Idempotency for retries/messages/webhooks
- Explicit timeouts for remote calls
- Retry policy for transient failures
- Circuit breaker / bulkhead only where justified
- Health endpoints
- Structured logs
- Metrics
- Distributed tracing
- Critical failure alerts
- Graceful shutdown
- Backup/recovery expectations
- Deployment rollback path
- Load/scale assumptions documented
- Security review for sensitive boundaries
