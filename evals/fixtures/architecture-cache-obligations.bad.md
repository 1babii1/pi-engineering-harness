Redis is generally faster, so add it.
services.AddStackExchangeRedisCache(o => o.Configuration = "localhost");
Wrap the query in IDistributedCache and cache for 10 minutes.
