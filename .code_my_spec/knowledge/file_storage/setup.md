# File Storage Setup: Tigris on Fly.io

This document covers everything needed to implement the Tigris-based file storage strategy decided in `docs/architecture/decisions/file_storage.md`. It is written for the MetricFlow project and references the actual modules, config files, and naming conventions in use.

## Overview

The two immediate use cases driving this integration:

1. **Agency white-label logos** — `MetricFlow.Agencies.WhiteLabelConfig.logo_url` stores a public Tigris object URL. The upload flow is browser-to-Tigris (direct upload) using a Phoenix LiveView presigned PUT URL. No file bytes pass through the Phoenix process.
2. **Report exports (deferred)** — same bucket, `reports/` prefix, private objects with presigned GET URLs.

---

## 1. Dependencies

Add these three packages to `mix.exs`. They do not exist in the project yet.

```elixir
# mix.exs — in the deps/0 list
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.3"},
{:sweet_xml, "~> 0.7"},
```

**Why all three:**

- `ex_aws` — core AWS SDK for Elixir; handles request signing (AWS Signature Version 4), credential resolution, and HTTP dispatch
- `ex_aws_s3` — S3-specific operations; needed for `ExAws.S3.presigned_url/5` and any object management calls
- `sweet_xml` — required by `ex_aws_s3` to parse XML responses from S3-compatible APIs (e.g., `ListObjectsV2` returns XML); without it, list operations raise a runtime error

**sweet_xml is optional in the package manifest but practically required.** S3 list/delete operations return XML. If you only ever generate presigned URLs and never call `ExAws.S3.list_objects`, you could skip it, but including it prevents future surprises.

After adding, run:

```bash
mix deps.get
```

---

## 2. Avoiding Hackney

The project uses `Req` as its HTTP client (see `AGENTS.md` — explicitly preferred, Hackney is excluded). The default HTTP adapter for `ex_aws` is `:hackney`. Left unconfigured, adding `ex_aws` would silently add Hackney as a transitive dependency.

`ex_aws ~> 2.5` ships `ExAws.Request.Req` — a first-party Req adapter. Configure it in `config/config.exs` so it applies to all environments:

```elixir
# config/config.exs
config :ex_aws,
  json_codec: Jason,
  http_client: ExAws.Request.Req
```

`Jason` is already a project dependency. `Req` is already a project dependency. This configuration means no new HTTP client dependencies are introduced.

**Optional Req tuning** — if you need to adjust timeouts for large uploads, this is the knob:

```elixir
config :ex_aws, :req_opts,
  receive_timeout: 60_000   # milliseconds; default is 15_000
```

**Test environment** — no special override needed. `ExAws.Request.Req` uses `Req` in tests just as in production. Upload-related tests should mock the presigned URL generation rather than making real HTTP calls (see the Testing section below).

---

## 3. Tigris Configuration

Tigris is S3-compatible. The only change from standard AWS S3 configuration is the host and region.

### 3a. Fly.io provisioning (one-time, run from repo root)

```bash
fly storage create --public
```

This command:
- Provisions a new Tigris bucket
- Makes it publicly readable (required for logo `<img src="...">` embedding)
- Automatically sets four Fly secrets on the app:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `BUCKET_NAME`
  - `AWS_ENDPOINT_URL_S3` (value: `https://fly.storage.tigris.dev`)

Verify the secrets were injected:

```bash
fly secrets list
```

All four should appear. No manual secret management is needed beyond this one command.

**Name the bucket intentionally.** Fly will prompt for a bucket name. Use something like `metricflow-assets` or `metricflow-prod`. The name becomes part of the public URL: `https://fly.storage.tigris.dev/{bucket-name}/{key}`.

**For a separate private reports bucket** (when report exports are implemented), run a second command without `--public`:

```bash
fly storage create
# name it: metricflow-reports
```

Store the separate credentials as different secret names (e.g., `REPORTS_BUCKET_NAME`, `REPORTS_AWS_ACCESS_KEY_ID`, etc.) since Fly auto-names secrets based on the bucket.

### 3b. runtime.exs configuration

Add the Tigris S3 endpoint config inside the `config_env() == :prod` block in `config/runtime.exs`:

```elixir
# config/runtime.exs — inside the `if config_env() == :prod do` block

config :ex_aws,
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "auto"
```

**Why `region: "auto"`:** Tigris is globally distributed. The `"auto"` region tells the Tigris API to route requests to the nearest region automatically. Standard AWS region strings like `"us-east-1"` will not work correctly with Tigris.

**Why not `AWS_ENDPOINT_URL_S3`:** The `fly storage create` command injects `AWS_ENDPOINT_URL_S3` as a Fly secret, but `ex_aws` does not read this environment variable automatically — it reads `:host` from the `:s3` config key. The explicit `host:` config above is required.

### 3c. dev/test environment

Do not configure Tigris credentials for the dev or test environments. Upload paths should be tested with mocks (see Testing section). In development, avoid real S3 calls; generate the presigned URL structure locally or stub it entirely.

If you need to test the actual Tigris connection locally, set environment variables manually and add a `config/dev.exs` override:

```elixir
# config/dev.exs — only if doing manual Tigris verification locally
# Do NOT commit real credentials here
config :ex_aws,
  access_key_id: System.get_env("TIGRIS_ACCESS_KEY_ID", "dev-key"),
  secret_access_key: System.get_env("TIGRIS_SECRET_ACCESS_KEY", "dev-secret")

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "auto"
```

---

## 4. MetricFlow.Storage Module

Wrap all storage operations in a dedicated module. This provides a mockable boundary for the test suite (via `Mox`) and keeps S3 details out of LiveView modules.

Create `lib/metric_flow/storage.ex`:

```elixir
defmodule MetricFlow.Storage do
  @moduledoc """
  File storage operations backed by Tigris (S3-compatible object storage).

  All public functions in this module should be mocked in tests using
  MetricFlow.StorageMock rather than making real HTTP calls to Tigris.
  """

  @callback presign_logo_upload(entry :: map()) ::
    {:ok, %{uploader: String.t(), key: String.t(), url: String.t()}}
    | {:error, term()}

  @callback public_url(key :: String.t()) :: String.t()

  @doc """
  Generates a presigned PUT URL for a logo upload entry from LiveView.

  The returned map is passed as upload metadata to Phoenix LiveView's external
  upload mechanism. The browser sends a PUT request directly to `url`.

  ## Parameters

    - `entry` — the `%Phoenix.LiveView.UploadEntry{}` struct from `allow_upload`

  ## Examples

      {:ok, meta} = MetricFlow.Storage.presign_logo_upload(entry)
      # => {:ok, %{uploader: "S3", key: "logos/my-logo.png", url: "https://..."}}

  """
  def presign_logo_upload(entry) do
    bucket = System.fetch_env!("BUCKET_NAME")
    key = "logos/#{entry.uuid}-#{entry.client_name}"

    config = ExAws.Config.new(:s3)

    case ExAws.S3.presigned_url(config, :put, bucket, key,
           expires_in: 300,
           query_params: [{"Content-Type", entry.client_type}]
         ) do
      {:ok, url} ->
        {:ok, %{uploader: "S3", key: key, url: url}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the public URL for a stored object key.

  Logo URLs are stored in WhiteLabelConfig.logo_url as the full public URL,
  so this function is used to build that URL after a successful upload.

  ## Examples

      MetricFlow.Storage.public_url("logos/abc123-company.png")
      # => "https://fly.storage.tigris.dev/metricflow-assets/logos/abc123-company.png"

  """
  def public_url(key) do
    bucket = System.fetch_env!("BUCKET_NAME")
    "https://fly.storage.tigris.dev/#{bucket}/#{key}"
  end
end
```

**Key implementation notes:**

- The key uses `entry.uuid` as a prefix to avoid filename collisions when multiple agencies upload similarly-named files (e.g., `logo.png`).
- `expires_in: 300` gives the browser 5 minutes to complete the upload. Increase this if you allow large files.
- `query_params: [{"Content-Type", entry.client_type}]` is required. The browser must include a `Content-Type` header matching the signed value; without it the presigned PUT will be rejected.

---

## 5. Phoenix LiveView Presigned Upload Flow

Phoenix LiveView's `allow_upload/3` with `external:` redirects the upload directly from the browser to Tigris. The Phoenix server only:
1. Generates the presigned URL (fast, no data transfer)
2. Receives the completion callback to save the resulting URL to the database

The file bytes never pass through the Phoenix/BEAM process.

### 5a. LiveView mount

In the agency settings LiveView (to be created at `lib/metric_flow_web/live/agency_live/settings.ex`):

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_logo_url, nil)
   |> allow_upload(:logo,
     accept: ~w(.jpg .jpeg .png .svg .webp),
     max_entries: 1,
     max_file_size: 2_000_000,   # 2 MB
     external: &presign_upload/2
   )}
end

defp presign_upload(entry, socket) do
  case MetricFlow.Storage.presign_logo_upload(entry) do
    {:ok, meta} -> {:ok, meta, socket}
    {:error, reason} -> {:error, reason}
  end
end
```

### 5b. Handle the save event

```elixir
@impl true
def handle_event("save_logo", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :logo, fn %{key: key}, _entry ->
      public_url = MetricFlow.Storage.public_url(key)
      {:ok, public_url}
    end)

  case uploaded_files do
    [logo_url] ->
      # Persist logo_url to WhiteLabelConfig
      # Agencies.update_white_label_config(scope, %{logo_url: logo_url})
      {:noreply,
       socket
       |> assign(:uploaded_logo_url, logo_url)
       |> put_flash(:info, "Logo uploaded successfully.")}

    [] ->
      {:noreply, put_flash(socket, :error, "No file was uploaded.")}
  end
end
```

### 5c. Template upload input

```heex
<form id="logo-upload-form" phx-submit="save_logo">
  <.live_file_input upload={@uploads.logo} />
  <button type="submit">Upload Logo</button>
</form>

<%= for entry <- @uploads.logo.entries do %>
  <div>
    <.live_img_preview entry={entry} width="120" />
    <span>{entry.client_name}</span>
    <progress value={entry.progress} max="100">{entry.progress}%</progress>
  </div>
<% end %>

<%= if @uploaded_logo_url do %>
  <img src={@uploaded_logo_url} alt="Current logo" class="h-12" />
<% end %>
```

### 5d. Client-side uploader (required)

Phoenix LiveView's external upload requires a JavaScript uploader hook named `"S3"` (matching the `uploader: "S3"` key returned by `presign_upload`). Add this to `assets/js/app.js`:

```javascript
// assets/js/app.js

const Uploaders = {}

Uploaders.S3 = function(entries, onViewError) {
  entries.forEach(entry => {
    let { url } = entry.meta
    let xhr = new XMLHttpRequest()

    onViewError(() => xhr.abort())

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        entry.progress(100)
      } else {
        entry.error()
      }
    }

    xhr.onerror = () => entry.error()

    xhr.upload.addEventListener("progress", event => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100)
        if (percent < 100) {
          entry.progress(percent)
        }
      }
    })

    xhr.open("PUT", url, true)
    xhr.setRequestHeader("Content-Type", entry.file.type)
    xhr.send(entry.file)
  })
}

// Pass uploaders to LiveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  // ... existing options ...
  uploaders: Uploaders
})
```

**Why PUT and not POST:** Tigris (and Cloudflare R2) do not support S3-style multipart POST form uploads via presigned URLs. The `ExAws.S3.presigned_url(:put, ...)` call generates a PUT URL; the client-side XHR must use `xhr.open("PUT", url)`. This is different from some older S3 tutorials that use `POST` with form data — those will not work with Tigris.

---

## 6. Public URL Pattern for Logo Serving

Once uploaded, a logo is accessible at:

```
https://fly.storage.tigris.dev/{bucket-name}/{key}
```

Example:
```
https://fly.storage.tigris.dev/metricflow-assets/logos/a1b2c3d4-company-logo.png
```

This URL is stored as-is in `WhiteLabelConfig.logo_url`. No auth headers are needed because the bucket was created with `--public`.

**Embedding in templates:**

```heex
<%= if @white_label_config.logo_url do %>
  <img
    src={@white_label_config.logo_url}
    alt={@white_label_config.company_name}
    class="h-8 w-auto"
  />
<% end %>
```

**CDN caching behavior:** Tigris automatically caches objects smaller than 128 KB at edge nodes globally based on access patterns. Most logos fall under this limit. There is no CDN configuration required — this caching happens transparently.

**Cache-busting:** If an agency replaces their logo, generate a new key (which `entry.uuid` prefix already ensures) rather than overwriting the existing object. Overwriting at the same key may result in stale cached versions being served for a period.

---

## 7. Testing

Do not call real Tigris endpoints in tests. The test environment has no `BUCKET_NAME` or AWS credentials, and making external HTTP calls in the test suite is fragile and slow.

### 7a. Define a behaviour and mock

Add to `lib/metric_flow/storage.ex` the `@callback` declarations shown in section 4, then in `test/support/` create a mock:

```elixir
# test/support/mocks.ex (or add to an existing mocks file)
Mox.defmock(MetricFlow.StorageMock, for: MetricFlow.Storage)
```

In `config/test.exs`, point the storage implementation to the mock:

```elixir
# config/test.exs
config :metric_flow, :storage, MetricFlow.StorageMock
```

In `lib/metric_flow/storage.ex`, read the implementation dynamically:

```elixir
# Alternative: use Application.get_env to allow mocking
defp storage_impl do
  Application.get_env(:metric_flow, :storage, MetricFlow.Storage)
end
```

Or use a simpler approach: have the LiveView call `MetricFlow.Storage` directly, and in tests stub the module function using `Mox.expect`.

### 7b. Testing the LiveView upload event

```elixir
# In a LiveView test for the agency settings page
import Mox

test "save_logo builds public URL and persists it", %{conn: conn} do
  MetricFlow.StorageMock
  |> expect(:presign_logo_upload, fn _entry ->
    {:ok, %{uploader: "S3", key: "logos/test-uuid-logo.png", url: "https://example.com/signed"}}
  end)
  |> expect(:public_url, fn "logos/test-uuid-logo.png" ->
    "https://fly.storage.tigris.dev/metricflow-assets/logos/test-uuid-logo.png"
  end)

  {:ok, view, _html} = live(conn, ~p"/agencies/settings")
  # ... test upload flow using Phoenix.LiveViewTest upload helpers ...
end
```

### 7c. What NOT to test

Do not test `ExAws.S3.presigned_url/5` directly — that is a library function, not your code. Test that `MetricFlow.Storage.presign_logo_upload/1` calls through correctly and returns the expected shape. Test that the LiveView calls `presign_upload/2` and correctly handles the returned metadata.

---

## 8. Complete Configuration Summary

After following the steps in this document, the changes across the project are:

**`mix.exs`:**
```elixir
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.3"},
{:sweet_xml, "~> 0.7"},
```

**`config/config.exs`** (add to existing file):
```elixir
config :ex_aws,
  json_codec: Jason,
  http_client: ExAws.Request.Req
```

**`config/runtime.exs`** (inside the `config_env() == :prod` block):
```elixir
config :ex_aws,
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "auto"
```

**New file:** `lib/metric_flow/storage.ex` (see section 4)

**`assets/js/app.js`:** Add `Uploaders.S3` hook and pass `uploaders: Uploaders` to LiveSocket (see section 5d)

**Fly.io (one-time CLI):**
```bash
fly storage create --public
```

---

## 9. Future: Report Export Files

When the `MetricFlow.Ai` report generator produces PDF or CSV exports, the same infrastructure handles it with minor additions:

- Store under `reports/{account_id}/{timestamp}-{filename}` key pattern
- Use a **separate private bucket** (created without `--public`) to enforce that reports are never publicly accessible
- Generate presigned GET URLs with short expiry (e.g., 900 seconds) via:

```elixir
ExAws.S3.presigned_url(config, :get, private_bucket, key, expires_in: 900)
```

- Link the user to this time-limited URL from the UI rather than embedding the file inline
- Add `REPORTS_BUCKET_NAME` to the set of application secrets

No code changes to the existing `MetricFlow.Storage` module are required for logos; report storage can be added as new functions in the same module or a separate `MetricFlow.Storage.Reports` submodule.
