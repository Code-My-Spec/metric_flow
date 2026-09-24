# Fix DNS resolution in test — the native resolver fails with nxdomain
# when Cloudflare Tunnel is running. Use Erlang's built-in DNS resolver
# which queries nameservers directly.
:inet_db.set_lookup([:dns, :native])

# `:needs_cassette` — a test whose recording is missing, or holds a response in
# a schema the code no longer produces. Neither can be repaired here: rewriting a
# recorded response records something the provider never said, and the providers
# in question need credentials and, in one case, money. Excluded rather than left
# red so a red suite means a real regression; `mix test --include needs_cassette`
# shows what is waiting on a recording. See .code_my_spec/TEST_FAILURES.md.
ExUnit.start(exclude: [:needs_cassette])
Ecto.Adapters.SQL.Sandbox.mode(MetricFlow.Repo, :manual)
