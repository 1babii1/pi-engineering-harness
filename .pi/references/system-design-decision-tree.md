# System Design Decision Tree

## Another service?
- Just code organization? -> module.
- Independent deployment/scaling/ownership/reliability/domain boundary? -> consider service.

## Sync or async?
- Caller needs result now -> HTTP/RPC.
- Caller can continue; need decoupling, fan-out, long work, spike absorption -> queue/event.

## Saga?
- One database transaction can solve it -> no.
- One business workflow spans autonomous services -> consider Saga + compensations.

## CQRS?
- Normal reads/writes are clear and fast -> no.
- Read model differs substantially and independently from write model -> consider.

## Cache/Redis?
- Database meets latency/load requirements -> no.
- Measured hot path, expensive repeated computation, or distributed ephemeral state -> consider.

## Kubernetes?
- Simple deployment / small system -> Docker/managed platform may be enough.
- Many workloads, autoscaling, HA, scheduling, standardized orchestration -> consider Kubernetes.
