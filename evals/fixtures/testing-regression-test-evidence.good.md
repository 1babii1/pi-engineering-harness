Seed 250 rows, more than the cap of 200, so a clamp and no clamp return different counts; assert
exactly 200 come back. To trust the test, break the fix (remove the clamp) and watch this exact test
go red, then restore the fix. A test seeded with fewer rows than the cap would pass both ways.
