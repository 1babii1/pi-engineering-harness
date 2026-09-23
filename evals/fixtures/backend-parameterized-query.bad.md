var sql = $"SELECT id, email FROM users WHERE email = '{email}'";
var user = connection.QuerySingleOrDefaultAsync<UserDto>(sql).Result;
