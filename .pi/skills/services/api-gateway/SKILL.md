---
name: api-gateway
description: Use for API gateway, BFF, edge routing, aggregation, and multi-service client architecture.
---
# API Gateway / BFF

Consider an API Gateway when multiple backend services need centralized external routing, auth termination, policy enforcement, rate limiting, or aggregation.

Consider BFF when web/mobile/other clients have materially different API needs.

Do not introduce a gateway for a single backend service without a concrete reason.

Avoid moving core business logic into the gateway.

If the gateway terminates authentication (validates the token, forwards identity headers/claims to
services), see `services/auth` for token validation requirements; downstream services still enforce
their own authorization - the gateway proving who the caller is does not decide what they may do.
