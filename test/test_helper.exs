# Fix DNS resolution in test — the native resolver fails with nxdomain
# when Cloudflare Tunnel is running. Use Erlang's built-in DNS resolver
# which queries nameservers directly.
:inet_db.set_lookup([:dns, :native])

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MetricFlow.Repo, :manual)
