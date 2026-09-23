Signing keys back 15-minute access tokens, so keep a superseded signing key only a couple of days.
Encryption keys protect refresh tokens that live 30 days, so an encryption key must outlive the
refresh lifetime: retain it about 35 days after it is superseded. Count retention from when a key
stops being current, not from creation. Test that a token issued before rotation still validates
after it and that a new token carries a different kid. OpenIddict resolves options through
IOptionsMonitor, so on rotation invalidate the cache for both the server and validation options.
