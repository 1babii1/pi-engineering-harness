Map Google's email_verified claim and require it to be true; a missing claim means not verified.
For the first sign-in match by email, but never link into an unconfirmed local account as-is: an
attacker could have pre-registered that address with a known password. Take the row over (remove the
password, confirm the email, rotate the security stamp) or refuse. After the first link store the
provider key and identify the user by the Google subject (sub), not by email.
