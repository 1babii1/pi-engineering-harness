Require the current password (re-authentication) before accepting the new one. After the change,
rotate the security stamp and revoke the user's other sessions and refresh tokens so an attacker's
session dies. Test it: sign in from a second browser, change the password in the first, and assert
the other session's cookie is rejected.
