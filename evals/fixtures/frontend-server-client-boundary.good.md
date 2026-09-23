Keep the page a Server Component (the default) and fetch the data and read the API key there -
server-only code never reaches the client bundle. Pass only the plain numeric likes value as a prop
into a small LikeButton component marked 'use client', since only it needs onClick/useState. The API
key itself is never passed as a prop and never sent to the browser.
