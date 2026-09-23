const [profile, setProfile] = useState(null);
useEffect(() => {
  fetch(`/api/profile/${id}`).then(r => r.json()).then(d => setProfile(d));
}, [id]);
