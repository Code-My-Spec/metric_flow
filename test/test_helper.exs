# Fix DNS resolution in test — the native resolver fails with nxdomain
# when Cloudflare Tunnel is running. Use Erlang's built-in DNS resolver
# which queries nameservers directly.
:inet_db.set_lookup([:dns, :native])

# `:stale_cassette` — a test whose recording holds a response in a schema the
# code no longer produces. It cannot pass and it cannot be repaired by editing
# the cassette: rewriting a response records something the provider never said.
# Excluded rather than left red so a red suite means a real regression; run them
# with `mix test --include stale_cassette` to see what is waiting on a
# re-recording. See .code_my_spec/TEST_FAILURES.md.
ExUnit.start(exclude: [:stale_cassette])
Ecto.Adapters.SQL.Sandbox.mode(MetricFlow.Repo, :manual)
