Wrap the check and insert in a lock (SemaphoreSlim); that is the fix and it solves the duplicates.
