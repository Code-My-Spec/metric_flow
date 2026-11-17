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
# `:e2e` — a real Playwright browser against a real listener; CMS_E2E turns
# it on (config/test.exs) and `--include e2e` runs it deliberately.
ExUnit.start(exclude: [:needs_cassette, :e2e])

# A real Chromium needs real built assets to request -- `priv/static` is
# gitignored and nothing else in `mix test`'s own path builds it. Without
# this, a fresh or cleaned checkout 404s app.js, the LiveView socket never
# connects, and the first chat message a stage waits on never arrives
# (demo walk, journey 66a06609, "Ask for a dashboard").
if System.get_env("CMS_E2E") in ~w(1 true) do
  {output, status} = System.cmd("mix", ["assets.build"], cd: File.cwd!(), stderr_to_stdout: true)

  if status != 0 do
    raise "mix assets.build failed ahead of a CMS_E2E run:\n#{output}"
  end
end

Ecto.Adapters.SQL.Sandbox.mode(MetricFlow.Repo, :manual)

MetricFlowTest.HermeticHttp.install()

# phoenix_test_playwright's Node driver; harmless when no :e2e test starts
# a browser pool from it. Mirrors CodeMySpecWeb's own test/test_helper.exs.
try do
  _ = PhoenixTest.Playwright.Supervisor.start_link()
  :ok
rescue
  _ -> :ok
end

Application.put_env(:phoenix_test, :base_url, MetricFlowWeb.Endpoint.url())
