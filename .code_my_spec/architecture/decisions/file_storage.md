# File Storage

**Status:** Proposed
**Date:** 2026-02-21

## Context

MetricFlow needs a file storage strategy for two use cases:

1. **Agency white-label logos** — the `MetricFlow.Agencies.WhiteLabelConfig` schema stores a `logo_url`. When an agency configures white-labeling, they need to upload a logo that is then served publicly at a stable URL, embedded in the application UI for tenants on that agency's subdomain.

2. **Report exports (future)** — the AI report generator (`MetricFlowWeb.ReportGenerator` LiveView and `MetricFlow.Ai` context) may produce PDF or CSV exports. These require either temporary signed download URLs or persistent storage per account.

The project deploys to Fly.io (per the [Deployment ADR](deployment.md)) and is at early SaaS stage with cost sensitivity. The existing stack uses `Req` for HTTP, `ex_aws_s3` is not currently a dependency. Any storage library that relies on Hackney (the default HTTP adapter for `ex_aws`) adds an HTTP client dependency that conflicts with the project's preference for Req.

### Key requirements

- Public URL serving for logos (must be directly embeddable in `<img src="...">` without auth)
- Phoenix LiveView `allow_upload` compatible presigned upload flow
- Signed URL support for any private files (future report exports)
- Minimal new dependencies — the project already uses Req
- Low cost at early scale (tens of logos, occasional report exports)
- No single-machine locality constraint — storage must be accessible from any Fly Machine

---

## Options Considered

### Option A: Tigris (Fly.io native S3-compatible object storage)

Tigris is Fly.io's first-party globally distributed object storage. It is S3-API-compatible. Running `fly storage create` automatically provisions a bucket and injects `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BUCKET_NAME`, and `AWS_ENDPOINT_URL_S3` as Fly secrets on the app — zero manual credential management.

**CDN behavior:** Tigris stores objects near the write region and automatically caches them near requesting users based on traffic patterns. Files under 128 KB (which covers most logos) are cached globally with no configuration required.

**Public bucket support:** Buckets can be made public at creation time (`fly storage create --public`). A public bucket provides direct `https://fly.storage.tigris.dev/{bucket}/{key}` URLs suitable for logo serving without any authentication.

**Elixir integration:** Tigris provides official documentation for the ExAWS Elixir SDK. The configuration replaces the default AWS host with `fly.storage.tigris.dev` and sets `region: "auto"`. Presigned URLs for Phoenix LiveView direct uploads are supported.

**Pricing (2025):** $0.02/GB/month storage; GET requests $0.0005/1,000. No egress fees. No minimum spend. At early scale (< 1 GB logos), storage cost is negligible — under $0.02/month.

**Pros:**
- Zero infrastructure setup: `fly storage create` and done
- Automatic CDN-like global caching without a separate CDN service
- No egress fees — logo serving is free regardless of traffic
- Secrets auto-injected into Fly app environment; no manual secret management
- Official Elixir SDK documentation with ExAWS configuration examples
- S3-compatible presigned URL flow works with `ExAws.S3.presigned_url/5`
- Deeply integrated with Fly.io deployment pipeline already chosen

**Cons:**
- Requires adding `ex_aws` and `ex_aws_s3` to `mix.exs`; both pull in Hackney by default (the HTTP adapter must be switched to Req or Finch to align with project HTTP client conventions — possible but requires explicit configuration)
- Tigris is a younger service than S3 or R2; less long-term track record
- If the project migrates off Fly.io, the `fly.storage.tigris.dev` endpoint changes (though Tigris also has a standalone `t3.storage.dev` endpoint independent of Fly)

---

### Option B: AWS S3

AWS S3 is the industry standard. The same `ex_aws` + `ex_aws_s3` library is used but configured against the standard AWS endpoint.

**Pricing (2025):** $0.023/GB/month storage (US-East); $0.09/GB egress after the first 100 GB/month free. At low volume this is low cost, but egress fees accumulate with logo serving traffic since every page load that displays a white-label logo hits S3 egress.

**Pros:**
- Industry-standard, extremely reliable
- All features (public buckets, presigned URLs, CloudFront CDN) are well-documented
- Widely used in the Elixir community; many tutorials available

**Cons:**
- Egress fees are a long-term cost concern for public logo serving — every request to a logo URL from outside AWS costs $0.09/GB
- Requires an AWS account with IAM user setup, access key management, and bucket policy configuration — more operational overhead than Tigris for a Fly.io-deployed app
- No native Fly.io integration; secrets must be manually added to Fly
- Adding CloudFront to eliminate egress costs adds further operational complexity (certificate, distribution configuration)
- Same `ex_aws` dependency friction as Tigris but with more setup work

---

### Option C: Cloudflare R2

Cloudflare R2 is an S3-compatible object storage with zero egress fees, a 10 GB/month free tier, and $0.015/GB/month standard storage pricing.

**Public URL serving:** R2 buckets can be made publicly accessible via a custom domain. However, the custom domain must be managed by Cloudflare DNS, which means `metricflow.app` or a subdomain would need to be on Cloudflare. The `r2.dev` public access URLs are rate-limited and explicitly not recommended for production. Using R2 public URLs with a custom domain therefore creates a dependency on Cloudflare for DNS management.

**Presigned URLs:** R2 supports S3-compatible presigned URLs via the S3 API endpoint (`https://<account-id>.r2.cloudflarestorage.com`). Presigned URLs work with the S3 API domain only — they cannot be used with custom domains. For authenticated private file access (future report exports), this is fine. For public logo serving, the path requires either enabling the full `r2.dev` URL (rate-limited) or routing through a Cloudflare Worker.

**Elixir integration:** R2 is S3-compatible, so `ex_aws` + `ex_aws_s3` works with the endpoint URL changed to the R2 endpoint. There are working community examples. For PUT-based presigned uploads from Phoenix LiveView, the `ExAws.S3.presigned_url(:put, ...)` pattern is used since R2 does not support S3-style POST form uploads.

**Pricing (2025):** 10 GB-month free, then $0.015/GB/month. Zero egress fees. Class A operations (PUT, POST): $4.50/million; Class B (GET): $0.36/million. Entirely free at early scale.

**Pros:**
- Zero egress fees — better than S3 for logo serving at any scale
- Very generous free tier (10 GB)
- Cheapest storage pricing of the S3-compatible options
- No AWS account required

**Cons:**
- Public logo serving at a non-rate-limited URL requires the DNS to be on Cloudflare — a significant operational constraint that couples DNS management to the storage provider
- Presigned URLs work only with the S3 API subdomain, not custom domains — inconsistent URL scheme if using both public bucket and signed URLs
- No native Fly.io integration; credentials must be manually provisioned
- Adds a second major cloud provider account (Cloudflare) alongside Fly.io; increases operational surface
- Same `ex_aws` dependency friction as the other S3 options

---

### Option D: Fly Volumes (persistent disk)

Fly Volumes are NVMe persistent disks attached to individual Fly Machines. Files written to a mounted volume path survive restarts and redeploys.

**Multi-machine limitation:** A Fly Volume is physically tied to one Machine in one region. Each Machine requires its own Volume. There is no shared volume accessible by multiple Machines. If the app runs two Machines (recommended by the Deployment ADR for availability), logos uploaded to Machine A's volume are invisible to Machine B unless additional replication is implemented.

**Serving:** Files on a volume are served by the Phoenix process via static file plug or a controller — the application itself serves every request, consuming BEAM memory and request-handling capacity.

**Pros:**
- No new dependencies
- Very low cost ($0.15/GB/month for NVMe-backed storage)
- Simple to implement for a single-machine deployment

**Cons:**
- Volumes are not shared across Machines — incompatible with running two or more Machines for availability without custom replication logic
- Serving files through the Phoenix process wastes BEAM resources on static file delivery
- No CDN caching — every logo request hits the Fly Machine
- Files are lost if the Machine is replaced or migrated; disaster recovery requires Volume snapshots (manual)
- Not appropriate for report exports where files may be large or numerous
- Fly docs explicitly recommend object storage (Tigris) over Volumes for file/asset storage

---

### Option E: PostgreSQL binary storage (database bytea column)

Logos are stored as `bytea` in a PostgreSQL column on the `white_label_configs` table. The application retrieves the binary and serves it via a controller endpoint.

**Performance characteristics:** PostgreSQL wiki recommends against storing large binary files in bytea. For small images (typical logo: 50–200 KB), retrieval is approximately 10x slower than reading from a filesystem. Every logo request triggers a database query and holds a database connection for the duration.

**Ecto integration:** Adding a `:binary` typed field to the `WhiteLabelConfig` schema and a corresponding `bytea` migration column works without additional dependencies. Phoenix LiveView's built-in (non-external) upload flow handles the server-side upload.

**Serving:** A Phoenix controller reads the bytea blob and streams it as the response with an appropriate `Content-Type` header. No external service needed.

**Pros:**
- Zero new dependencies
- Simplest implementation — no external service credentials or API client needed
- Logos travel with database backups automatically
- Works correctly across multiple Fly Machines (shared PostgreSQL)

**Cons:**
- Database connection consumed for every logo request, including page loads by all users of that agency's subdomain
- No CDN; every request hits the Fly Machine and then the database
- Database size grows with every logo stored; Fly Managed Postgres storage is billed at $0.15/GB/month — more expensive per GB than object storage
- Report export files (PDFs, CSVs) would be impractical to store in bytea due to size
- Does not scale cleanly: logo serving should be offloaded from the primary request path as traffic grows, making bytea storage a technical debt item that must be migrated eventually
- Phoenix serves the file inline — no opportunity for client-side caching headers without explicit work in the controller

---

## Decision

**Tigris is recommended as the file storage provider.**

Tigris is the correct choice for a project deploying to Fly.io at early stage:

1. **Zero configuration overhead.** `fly storage create --public` provisions the bucket and injects all secrets into the app in one command. There is no IAM console, no access key rotation workflow, and no manual secret management beyond what `fly secrets` already handles.

2. **Automatic CDN behavior for logos.** Logos (< 128 KB) are cached globally by Tigris with no CDN configuration. Every agency's white-label logo load is served from an edge node near the end user. This is the correct serving strategy for `<img src="...">` resources embedded in every page load.

3. **Zero egress fees.** Logo serving at any traffic volume costs nothing beyond the storage footprint. AWS S3 would accumulate egress charges as agencies onboard and traffic grows.

4. **No locality constraint.** Unlike Fly Volumes, a Tigris bucket is accessible from any Fly Machine in any region. The two-machine availability configuration from the Deployment ADR works without any coordination logic.

5. **Aligned with project deployment platform.** The Deployment ADR chose Fly.io specifically for its Phoenix ecosystem integration. Tigris is Fly.io's native storage offering, documented for Elixir in the Phoenix Files series and with an official ExAWS SDK guide.

Cloudflare R2 has better pricing (larger free tier, slightly lower per-GB cost) but introduces a DNS coupling requirement for production public URL serving. That constraint — migrating DNS to Cloudflare to get non-rate-limited public bucket URLs — adds operational complexity that outweighs the marginal cost advantage at early scale. AWS S3 has the best long-term track record but imposes egress fees and requires more manual AWS account management.

Database storage is rejected for logos because it consumes database connections on every page load and cannot be extended to report exports. Fly Volumes are rejected because they cannot be shared across Machines.

### Library choice

Add `ex_aws` and `ex_aws_s3` to `mix.exs`. These are the standard Elixir S3 libraries (actively maintained through December 2025, with regular 2025 releases). Configure `ex_aws` to use `Req` as its HTTP adapter rather than the default Hackney:

```elixir
# mix.exs
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.3"},
{:sweet_xml, "~> 0.7"},   # required by ex_aws_s3 for XML response parsing
```

```elixir
# config/config.exs
config :ex_aws,
  json_codec: Jason,
  http_client: ExAws.Request.Req   # use Req instead of Hackney
```

> Note: `ExAws.Request.Req` requires `ex_aws ~> 2.5` or later which added Req adapter support. Confirm the adapter name in the ExAWS changelog when integrating.

Alternatively, if Req adapter support is not available in the targeted `ex_aws` version, configure Hackney as a separate dep scoped only to `:prod` and `:dev` (not `:test`). A lighter option is to implement a minimal presigned URL module using only `Req` and the standard AWS Signature Version 4 algorithm — this avoids `ex_aws` entirely for the limited use case of logo uploads and presigned URL generation.

### Tigris configuration

```elixir
# config/runtime.exs (production)
config :ex_aws,
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")

config :ex_aws, :s3,
  scheme: "https://",
  host: "fly.storage.tigris.dev",
  region: "auto"
```

The `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BUCKET_NAME`, and `AWS_ENDPOINT_URL_S3` secrets are injected automatically by `fly storage create`.

### Phoenix LiveView upload flow

Use Phoenix LiveView's external upload mechanism with a presigned PUT URL for direct browser-to-Tigris uploads. The server generates a presigned URL; the browser uploads the file directly without routing bytes through the Phoenix process.

```elixir
# In the agency settings LiveView
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> allow_upload(:logo,
     accept: ~w(.jpg .jpeg .png .svg .webp),
     max_entries: 1,
     max_file_size: 2_000_000,
     external: &presign_logo_upload/2
   )}
end

defp presign_logo_upload(entry, socket) do
  bucket = System.fetch_env!("BUCKET_NAME")
  key = "logos/#{entry.client_name}"

  {:ok, presigned_url} =
    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:put, bucket, key,
      expires_in: 300,
      query_params: [{"Content-Type", entry.client_type}]
    )

  meta = %{
    uploader: "S3",
    key: key,
    url: presigned_url
  }

  {:ok, meta, socket}
end
```

After the upload completes, save the public object URL to `WhiteLabelConfig.logo_url`:

```elixir
"https://fly.storage.tigris.dev/#{bucket}/#{key}"
```

The client-side JavaScript uploader sends a PUT request with the file body directly to the presigned URL (not a multipart form POST, since both Tigris and R2 require PUT for presigned uploads).

---

## Consequences

**Dependencies added:**
- `{:ex_aws, "~> 2.5"}` and `{:ex_aws_s3, "~> 2.3"}` and `{:sweet_xml, "~> 0.7"}` added to `mix.exs`
- HTTP adapter must be explicitly configured to avoid adding Hackney; verify Req adapter availability in the chosen ex_aws version

**Fly.io setup (one-time):**
- Run `fly storage create --public` to create the Tigris bucket and auto-inject secrets
- Verify the four secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BUCKET_NAME`, `AWS_ENDPOINT_URL_S3`) are present in `fly secrets list`

**Schema change:**
- `MetricFlow.Agencies.WhiteLabelConfig` stores `logo_url` as a plain string (the public Tigris object URL); no binary data enters the database

**Test suite:**
- Upload tests should mock the presigned URL generation step; avoid hitting Tigris in the test environment
- A `MetricFlow.Storage` module wrapping `ExAws.S3.presigned_url` makes this mockable via `Mox` or a simple test stub

**Report exports (deferred):**
- When report export is implemented, the same Tigris bucket can store export files under a `reports/` prefix
- Report objects should be stored in a private bucket (or a separate bucket with no public access) and served via presigned GET URLs with short expiry (e.g., 15 minutes)
- Consider a separate `reports` bucket created without `--public` to enforce access control at the bucket level

**Future migration:**
- If the project leaves Fly.io, Tigris also provides a standalone endpoint (`t3.storage.dev`) independent of Fly infrastructure; migration would require updating the `:s3, host:` config value and re-provisioning credentials, but no code changes
