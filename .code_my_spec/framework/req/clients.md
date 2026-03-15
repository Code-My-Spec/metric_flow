# Req HTTP Clients

## Sources
- https://hexdocs.pm/req/Req.html
- https://hexdocs.pm/req/Req.Request.html
- https://hexdocs.pm/req/Req.Steps.html

---

## Philosophy

Write minimal Req client modules — thin wrappers around `Req.new/1` that configure base URL, auth, and headers. Each integration gets one client module. Business logic stays in the context; the client only handles HTTP transport.

---

## Minimal Client Pattern

```elixir
defmodule MyApp.GitHub.Client do
  @moduledoc """
  HTTP client for the GitHub API.
  """

  def new(token, opts \\ []) do
    Req.new(
      base_url: "https://api.github.com",
      auth: {:bearer, token},
      headers: [accept: "application/vnd.github.v3+json"],
      decode_json: [keys: :strings],
      retry: :transient,
      max_retries: 3,
      receive_timeout: 15_000
    )
    |> maybe_plug(opts)
  end

  def get_repo(client, owner, repo) do
    Req.get(client, url: "/repos/#{owner}/#{repo}")
  end

  def create_issue(client, owner, repo, attrs) do
    Req.post(client, url: "/repos/#{owner}/#{repo}/issues", json: attrs)
  end

  # Test support — pass `plug:` through opts for cassette recording
  defp maybe_plug(req, opts) do
    case Keyword.get(opts, :plug) do
      nil -> req
      plug -> Req.merge(req, plug: plug)
    end
  end
end
```

### Key conventions

| Convention | Pattern |
|---|---|
| Constructor | `new/1` or `new/2` — returns `%Req.Request{}` |
| Auth | Pass token to `new/1`, never hardcode |
| Base URL | Set in `new/1`, individual functions use relative paths |
| JSON keys | `:strings` for external APIs (you don't control the keys) |
| Test hook | Accept `opts` with optional `:plug` for cassette injection |
| Methods | One function per API endpoint, returns `{:ok, resp}` or `{:error, exc}` |
| No bang | Use `Req.get/2` not `Req.get!/2` — let callers decide error handling |

---

## Client with Dynamic Base URL

For services where the URL comes from config or runtime (OAuth servers, self-hosted APIs):

```elixir
defmodule MyApp.Integrations.SlackClient do
  def new(opts) do
    Req.new(
      base_url: opts[:base_url] || default_base_url(),
      auth: {:bearer, opts[:token]},
      headers: [content_type: "application/json; charset=utf-8"],
      decode_json: [keys: :strings],
      retry: :transient,
      max_retries: 2
    )
    |> maybe_plug(opts)
  end

  def post_message(client, channel, text) do
    Req.post(client, url: "/api/chat.postMessage", json: %{channel: channel, text: text})
  end

  defp default_base_url, do: "https://slack.com"

  defp maybe_plug(req, opts) do
    case Keyword.get(opts, :plug) do
      nil -> req
      plug -> Req.merge(req, plug: plug)
    end
  end
end
```

---

## Client with Scope (CodeMySpec pattern)

When the client needs project/account context via headers:

```elixir
defmodule CodeMySpec.Stories.RemoteClient do
  alias CodeMySpec.Auth.OAuthClient
  alias CodeMySpec.Users.Scope

  def new(%Scope{} = scope, opts \\ []) do
    {:ok, token} = OAuthClient.get_token()

    Req.new(
      base_url: get_base_url(),
      headers: build_headers(token, scope),
      decode_json: [keys: :strings],
      retry: :transient,
      max_retries: 3
    )
    |> maybe_plug(opts)
  end

  def list_project_stories(client) do
    Req.get(client, url: "/api/stories-list/project")
  end

  defp build_headers(token, %Scope{active_project_id: pid}) when is_binary(pid) do
    [authorization: "Bearer #{token}", "x-project-id": pid]
  end

  defp build_headers(token, _scope) do
    [authorization: "Bearer #{token}"]
  end

  defp get_base_url do
    Application.get_env(:code_my_spec, :base_url, "https://dev.codemyspec.com")
  end

  defp maybe_plug(req, opts) do
    case Keyword.get(opts, :plug) do
      nil -> req
      plug -> Req.merge(req, plug: plug)
    end
  end
end
```

Usage from the context:

```elixir
def list_project_stories(%Scope{} = scope) do
  client = RemoteClient.new(scope)

  case RemoteClient.list_project_stories(client) do
    {:ok, %{status: 200, body: %{"data" => stories}}} ->
      {:ok, Enum.map(stories, &deserialize_story/1)}

    {:ok, %{status: status}} ->
      {:error, {:unexpected_status, status}}

    {:error, reason} ->
      {:error, reason}
  end
end
```

---

## Req.new/1 — Key Options Reference

### URL & Routing

| Option | Type | Description |
|---|---|---|
| `:base_url` | string | Prepended to `:url` on each request |
| `:url` | string | Per-request path (relative when base_url set) |
| `:params` | keyword | Appended as query string |
| `:path_params` | keyword | Template path vars (`:id` or `{id}` style) |

### Auth

| Option | Type | Description |
|---|---|---|
| `{:bearer, token}` | tuple | Bearer token in Authorization header |
| `{:basic, "user:pass"}` | tuple | Basic auth |
| `:netrc` | atom | Read credentials from ~/.netrc |

### Body Encoding

| Option | Type | Description |
|---|---|---|
| `:json` | map/list | Encode as JSON, sets Content-Type |
| `:form` | keyword | Encode as x-www-form-urlencoded |
| `:form_multipart` | keyword | Encode as multipart/form-data |

### Response Decoding

| Option | Type | Default | Description |
|---|---|---|---|
| `:decode_body` | boolean | `true` | Auto-decode by content-type |
| `:decode_json` | keyword | `[]` | Options for JSON decoder (e.g. `keys: :strings`) |
| `:raw` | boolean | `false` | Skip decompression and decoding |

### Retry

| Option | Type | Default | Description |
|---|---|---|---|
| `:retry` | atom/fn | `:safe_transient` | `:safe_transient`, `:transient`, custom fn, or `false` |
| `:max_retries` | integer | `3` | Max retry attempts |
| `:retry_delay` | function | exponential | `fn(retry_count) -> delay_ms` |

`:safe_transient` retries GET/HEAD on transient errors (408, 429, 500, 503, network).
`:transient` retries all methods on transient errors.

### Connection

| Option | Type | Default | Description |
|---|---|---|---|
| `:receive_timeout` | integer | `15_000` | Socket receive timeout (ms) |
| `:pool_timeout` | integer | `5_000` | Pool checkout timeout (ms) |
| `:connect_options` | keyword | `[]` | TLS, proxy, protocol options |

### Error Handling

| Option | Type | Default | Description |
|---|---|---|---|
| `:http_errors` | atom | `:return` | `:return` (4xx/5xx as normal) or `:raise` |

### Testing

| Option | Type | Description |
|---|---|---|
| `:plug` | module/fn | Route to Plug instead of real HTTP (cassette injection point) |

---

## Response Handling Patterns

### Pattern match on status

```elixir
case Req.get(client, url: "/resource/#{id}") do
  {:ok, %{status: 200, body: body}} -> {:ok, body}
  {:ok, %{status: 404}} -> {:error, :not_found}
  {:ok, %{status: 401}} -> {:error, :unauthorized}
  {:ok, %{status: status, body: body}} -> {:error, {:unexpected_status, status, body}}
  {:error, exception} -> {:error, exception}
end
```

### Req.Response fields

```elixir
%Req.Response{
  status: 200,          # integer
  headers: %{},         # downcased name => [values]
  body: term,           # decoded by default (map for JSON)
  trailers: %{},
  private: %{}
}
```

---

## Req.merge/2 — Updating Clients

`Req.merge/2` merges options into an existing request. Headers and params are **merged** (additive), other options are **overwritten**.

```elixir
client = MyClient.new(token)

# Add per-request params
Req.get(Req.merge(client, params: [page: 2, per_page: 50]), url: "/items")

# Or just pass options directly — Req functions merge automatically
Req.get(client, url: "/items", params: [page: 2])
```

---

## Custom Steps (Plugins)

For cross-cutting concerns (logging, metrics, custom auth). Export `attach/1`:

```elixir
defmodule MyApp.Req.LogStep do
  def attach(request) do
    request
    |> Req.Request.append_request_steps(log_request: &log_request/1)
    |> Req.Request.append_response_steps(log_response: &log_response/1)
  end

  defp log_request(request) do
    Logger.debug("[HTTP] #{request.method |> to_string() |> String.upcase()} #{request.url}")
    request
  end

  defp log_response({request, response}) do
    Logger.debug("[HTTP] #{response.status} #{request.url}")
    {request, response}
  end
end

# Attach to any client:
Req.new(base_url: "https://api.example.com") |> MyApp.Req.LogStep.attach()
```

### Step function signatures

| Phase | Signature | Returns |
|---|---|---|
| Request step | `fn(request)` | `request` or `{request, response}` (short-circuit) |
| Response step | `fn({request, response})` | `{request, response}` |
| Error step | `fn({request, exception})` | `{request, exception}` or `{request, response}` |

---

## Localhost HTTPS (Dev)

When connecting to localhost with self-signed certs:

```elixir
def new(opts) do
  base_url = opts[:base_url] || "https://localhost:4001"

  Req.new(
    base_url: base_url,
    connect_options: ssl_opts(base_url)
  )
end

defp ssl_opts("https://localhost" <> _), do: [transport_opts: [verify: :verify_none]]
defp ssl_opts(_), do: []
```

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Inline `Req.get(url: "https://...", headers: [...])` everywhere | Build a client module with `new/1` |
| Hardcode tokens | Pass to `new/1`, read from config/env |
| Use `Req.get!` in library code | Use `Req.get` — let callers decide error handling |
| Parse JSON manually | Use `:decode_json` option on the client |
| Ignore the plug opt | Always accept `opts` with `:plug` for testability |
| Put HTTP logic in contexts | Keep it in the client module, contexts call client |
