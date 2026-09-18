---
name: distributed-systems
description: Use for replication, partitioning, consistency, queues, streams, distributed data, and DDIA-style trade-offs.
---
# Distributed Systems

Before selecting a design, determine:
- consistency model
- read/write ratio
- latency and throughput requirements
- durability requirements
- ordering requirements
- failure model
- data volume/growth
- availability requirements

Remember:
- Networks fail and messages may be delayed, duplicated, or reordered.
- A worker/process can crash at any point.
- Retries create duplicate-execution risk.
- "Exactly once" usually depends on idempotency and carefully defined boundaries.
- Replication, partitioning, queues, streams, caches, and consensus each trade simplicity for specific benefits.

Prefer local consistency and simple storage until distributed guarantees are truly required.
