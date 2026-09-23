var user = await connection.QuerySingleOrDefaultAsync<UserDto>(
    "SELECT id, email FROM users WHERE email = @email", new { email }, cancellationToken: ct);
