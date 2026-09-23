A successful dotnet build only proves the code compiles. It says nothing about the migration. Run the
migration against a restore of representative existing production data: historical rows may already
contain duplicates that make the unique constraint fail, so query for duplicates first and decide
how to clean them. Also check lock time on a large table in production.
