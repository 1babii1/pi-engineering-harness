const { data, isPending, error } = useQuery({
  queryKey: ['profile', id],
  queryFn: () => api.getProfile(id),
});
if (isPending) return <Spinner />;
if (error) return <ErrorState error={error} />;
return <Profile user={data} />;
