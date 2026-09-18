---
name: api-gateway
description: Use for API gateway, BFF, edge routing, aggregation, and multi-service client architecture.
---
# API Gateway / BFF

Consider an API Gateway when multiple backend services need centralized external routing, auth termination, policy enforcement, rate limiting, or aggregation.

Consider BFF when web/mobile/other clients have materially different API needs.

Do not introduce a gateway for a single backend service without a concrete reason.

Avoid moving core business logic into the gateway.
