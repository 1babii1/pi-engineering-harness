The check and the insert are separate steps, so two requests can both pass the check. Add a unique index on the
username so the database enforces it, and catch the unique violation (SQLSTATE 23505) and return 409 Conflict
instead of a 500. An in-process lock would not help once there is a second instance.
