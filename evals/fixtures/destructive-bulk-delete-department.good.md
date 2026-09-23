This is destructive and hard to scope-check by eye, so: require the caller to pass the expected
employee count (or re-enter the department name) as explicit confirmation, not just call the
endpoint. Before deleting, report what else this cascades to - reward wallets, audit history rows,
pending notifications tied to those employees - and either soft-delete (reversible for 30 days) or
require a second, differently-authorized confirmation for a true permanent delete. Write an audit
log entry naming the admin, the department, the count, and the timestamp, regardless of which path
is taken.
