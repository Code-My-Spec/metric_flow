# ReqCassette — Record/Replay HTTP for Tests

## Sources
- https://hexdocs.pm/req_cassette/readme.html
- https://hexdocs.pm/req/Req.Test.html

---

## Philosophy

**Record everything.** Every external HTTP call in every test should go through a cassette. No hand-crafted mocks, no stubs, no fake responses. Record the real interaction once, replay it forever. This gives you confidence that your code works against real API responses, not your assumptions about them.

---

## Setup

### Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:req, "~> 0.5"},
    {:req_cassette, "~> 0.5", only: :test}
  ]
end
```

### Directory

Cassettes default to `test/cassettes/`. Create it:

```bash
mkdir -p test/cassettes
```

---

## Core Pattern: `with_cassette/2`

```elixir
import ReqCassette

test "fetches user data" do
  with_cassette "github_user", fn plug ->
    response = Req.get!("https://api.github.com/users/wojtekmach", plug: plug)
    assert response.status == 200
    assert response.body["login"] == "wojtekmach"
  end
end
```

The `plug` argument is passed to Req via the `:plug` option. On first run, the real HTTP call is made and recorded. On subsequent runs, the cassette is replayed.

---

## Integration with Client Modules

The key pattern: client `new/1` accepts `opts` with an optional `:plug`. Tests pass the cassette plug through opts. In production, no plug — real HTTP. In tests, always a cassette plug.

### Client module

```elixir
defmodule MyApp.GitHub.Client do
  def new(token, opts \\ []) do
    Req.new(
      base_url: "https://api.github.com",
      auth: {:bearer, token},
      headers: [accept: "application/vnd.github.v3+json"],
      decode_json: [keys: :strings]
    )
    |> maybe_plug(opts)
  end

  def get_repo(client, owner, repo) do
    Req.get(client, url: "/repos/#{owner}/#{repo}")
  end

  defp maybe_plug(req, opts) do
    case Keyword.get(opts, :plug) do
      nil -> req
      plug -> Req.merge(req, plug: plug)
    end
  end
end
```

### Test

```elixir
defmodule MyApp.GitHub.ClientTest do
  use ExUnit.Case, async: true

  import ReqCassette

  describe "get_repo/3" do
    test "returns repo data" do
      with_cassette "github_get_repo", fn plug ->
        client = MyApp.GitHub.Client.new("test-token", plug: plug)
        assert {:ok, %{status: 200, body: body}} = MyApp.GitHub.Client.get_repo(client, "owner", "repo")
        assert body["full_name"] == "owner/repo"
      end
    end

    test "handles not found" do
      with_cassette "github_get_repo_not_found", fn plug ->
        client = MyApp.GitHub.Client.new("test-token", plug: plug)
        assert {:ok, %{status: 404}} = MyApp.GitHub.Client.get_repo(client, "owner", "nonexistent")
      end
    end
  end
end
```

### Context test (integration)

When testing through the context layer, thread `:plug` via opts all the way down:

```elixir
defmodule MyApp.StoriesTest do
  use MyApp.DataCase, async: true

  import ReqCassette

  test "list_project_stories/2 returns stories" do
    scope = user_scope_fixture()

    with_cassette "stories_list_project", fn plug ->
      assert {:ok, stories} = MyApp.Stories.list_project_stories(scope, plug: plug)
      assert length(stories) > 0
    end
  end
end
```

---

## Recording Modes

| Mode | Behavior | When to Use |
|---|---|---|
| `:record` | Record missing, replay existing | Default — local dev |
| `:replay` | Replay only, error if missing | CI — no network calls |
| `:bypass` | Skip cassettes, always hit network | Debugging a flaky cassette |

```elixir
# Force replay (CI)
with_cassette "api_call", [mode: :replay], fn plug ->
  Req.get!("https://api.example.com/data", plug: plug)
end

# Force re-record
with_cassette "api_call", [mode: :record], fn plug ->
  Req.get!("https://api.example.com/data", plug: plug)
end
```

### CI configuration

Set mode globally via config:

```elixir
# config/test.exs
config :req_cassette, mode: :replay
```

Or per-test via options as shown above.

---

## Cassette File Format

Cassettes are pretty-printed JSON — human-readable, diffable, safe to commit:

```json
{
  "version": "1.0",
  "interactions": [
    {
      "request": {
        "method": "GET",
        "uri": "https://api.github.com/repos/owner/repo",
        "headers": {"accept": ["application/vnd.github.v3+json"]},
        "body_type": "text",
        "body": ""
      },
      "response": {
        "status": 200,
        "headers": {"content-type": ["application/json"]},
        "body_type": "json",
        "body_json": {"id": 1, "full_name": "owner/repo"}
      },
      "recorded_at": "2025-10-16T12:00:00Z"
    }
  ]
}
```

Body types: `json` (native objects), `text` (plain), `blob` (base64 binary).

---

## Multiple Requests Per Cassette

Group related API calls in one cassette:

```elixir
with_cassette "create_and_verify_issue", fn plug ->
  client = GitHub.Client.new(token, plug: plug)

  {:ok, %{status: 201, body: created}} =
    GitHub.Client.create_issue(client, "owner", "repo", %{title: "Bug"})

  {:ok, %{status: 200, body: fetched}} =
    GitHub.Client.get_issue(client, "owner", "repo", created["number"])

  assert fetched["title"] == "Bug"
end
```

---

## Request Matching

Default match fields: `:method`, `:uri`, `:query`, `:headers`, `:body`.

Relax matching when headers or body vary between runs:

```elixir
# Match only on method + URI (ignore auth headers, timestamps in body)
with_cassette "flexible_match", [match_requests_on: [:method, :uri]], fn plug ->
  Req.get!("https://api.example.com/data", plug: plug)
end
```

---

## Sequential Mode

For APIs that return different responses to identical requests (polling, pagination):

```elixir
with_cassette "polling_status", [sequential: true], fn plug ->
  assert {:ok, %{body: %{"status" => "pending"}}} = Req.get(url, plug: plug)
  assert {:ok, %{body: %{"status" => "running"}}} = Req.get(url, plug: plug)
  assert {:ok, %{body: %{"status" => "complete"}}} = Req.get(url, plug: plug)
end
```

---

## Filtering Sensitive Data

Never commit tokens, API keys, or cookies to cassette files:

```elixir
with_cassette "authenticated_call", [
  filter_request_headers: ["authorization", "x-api-key", "cookie"],
  filter_response_headers: ["set-cookie"],
  filter_sensitive_data: [
    {~r/token=[^&]+/, "token=<REDACTED>"},
    {~r/"api_key":"[^"]+"/u, ~s("api_key":"<REDACTED>")}
  ]
], fn plug ->
  Req.get!("https://api.example.com/data",
    plug: plug,
    auth: {:bearer, real_token}
  )
end
```

---

## Templated Matching (Dynamic Values)

Handle UUIDs, timestamps, and other dynamic values so the same cassette works across runs:

```elixir
with_cassette "get_resource", [
  template: [patterns: [
    uuid: ~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i,
    timestamp: ~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/
  ]]
], fn plug ->
  # Different UUIDs will match the same recorded interaction
  Req.get!("https://api.example.com/resources/#{Ecto.UUID.generate()}", plug: plug)
end
```

---

## Async / Cross-Process Tests

When code under test spawns processes (Task.async, GenServer):

```elixir
setup do
  session = ReqCassette.start_shared_session()
  on_exit(fn -> ReqCassette.end_shared_session(session) end)
  %{session: session}
end

test "parallel API calls", %{session: session} do
  with_cassette "parallel_fetch", [session: session, sequential: true], fn plug ->
    tasks = Enum.map(1..3, fn id ->
      Task.async(fn ->
        Req.get!("https://api.example.com/items/#{id}", plug: plug)
      end)
    end)

    results = Task.await_many(tasks)
    assert Enum.all?(results, &(&1.status == 200))
  end
end
```

---

## Cassette Naming Convention

| Pattern | Example |
|---|---|
| `{service}_{operation}` | `github_get_repo` |
| `{service}_{operation}_{scenario}` | `github_get_repo_not_found` |
| `{context}_{function}` | `stories_list_project` |
| `{test_module}_{test_name}` | `remote_client_list_stories` |

Keep names lowercase, underscored, descriptive. One cassette per logical interaction.

---

## Re-Recording Cassettes

Delete the cassette file and re-run the test (with real network access):

```bash
# Re-record a single cassette
rm test/cassettes/github_get_repo.json
mix test test/my_app/github/client_test.exs

# Re-record all cassettes
rm -rf test/cassettes/*.json
mix test --include cassette
```

---

## with_cassette Options Reference

| Option | Type | Default | Description |
|---|---|---|---|
| `:cassette_dir` | string | `"test/cassettes"` | Storage directory |
| `:mode` | atom | `:record` | `:record`, `:replay`, or `:bypass` |
| `:match_requests_on` | list | all fields | `:method`, `:uri`, `:query`, `:headers`, `:body` |
| `:sequential` | boolean | `false` | Ordered replay for identical requests |
| `:template` | keyword | `nil` | `[patterns: [name: ~r/pattern/]]` |
| `:filter_request_headers` | list | `[]` | Header names to redact in cassettes |
| `:filter_response_headers` | list | `[]` | Header names to redact in cassettes |
| `:filter_sensitive_data` | list | `[]` | `[{regex, replacement}]` pairs |
| `:before_record` | function | `nil` | `fn(interaction) -> interaction` |
| `:session` | session | `nil` | Shared session for cross-process |

---

## Migration from ExVCR

| ExVCR | ReqCassette |
|---|---|
| `use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney` | `import ReqCassette` |
| `use_cassette "name" do ... end` | `with_cassette "name", fn plug -> ... end` |
| Global mock (`:meck`) | Per-request `:plug` option |
| Not async-safe | `async: true` compatible |
| Cassette dir: `test/fixtures/vcr_cassettes/` | Cassette dir: `test/cassettes/` |
| `ExVCR.Config.filter_sensitive_data(...)` | `filter_sensitive_data: [...]` option |

Key difference: ReqCassette requires threading `plug` through your code. This is the tradeoff — explicit injection instead of global interception — and why client modules need the `opts` pattern with `:plug`.
