Ten microservices, Kafka, Redis and sharding are not justified for three developers and about 1,000
users. Start with a modular monolith on one PostgreSQL database with clear module boundaries.
Revisit when there are real triggers: independent scaling needs, a second team owning a module, or
measured load that one instance cannot carry. Until then extra moving parts only add failure modes.
