A leaked database dump or backup gives an attacker the private keys, so they can forge access tokens and decrypt
refresh tokens. Encrypt the PEM with AES-256-GCM using a master key that lives outside the database (secret
manager or an environment secret), bind the ciphertext to the row with associated data, refuse to start in
Production without the master key, and re-encrypt existing plaintext rows on startup.
