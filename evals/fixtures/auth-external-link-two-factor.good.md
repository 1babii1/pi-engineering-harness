The email match alone must not sign the user in when TOTP is enabled: on the first link, create the link and then
send the user through the normal second-factor challenge so they must enter a valid code. Later sign-ins with the
already-linked Google login can skip a second challenge, since Google itself is a strong factor.
