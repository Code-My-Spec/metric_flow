# Report Export: Setup and Implementation Guide

This file covers all of Phase 1 report export for MetricFlow and documents the Phase 2 upgrade
path. Read alongside `docs/architecture/decisions/report_export.md` which explains why the phased
approach was chosen.

---

## Overview

MetricFlow reports are a combination of Vega-Lite chart specs (stored as `%{}` maps in the
`Visualization` schema's `vega_spec` field) and narrative text. The LLM generates both; the
browser renders them via `vega-embed`. Phase 1 export works entirely in the browser — no new
server-side dependencies, no Docker image changes, no Fly.io memory pressure.

Phase 1 export surfaces:

1. **Browser print / Save as PDF** — a "Print / Save as PDF" button calls `window.print()`. The
   browser renders the report page, including Vega-Lite SVG charts, into a PDF via its native
   print pipeline.
2. **CSV download** — a "Download CSV" button hits a Phoenix controller that streams the metric
   rows underlying the report as a CSV attachment.

Phase 2 (deferred) upgrades the PDF path to ChromicPDF running headless Chromium server-side once
the report template is stable and user demand is confirmed.

---

## Phase 1: Browser Print

### Why Browser Print Works for Vega-Lite

`vega-embed` renders Vega-Lite specs to SVG by default (pass `renderer: "svg"` to confirm this
explicitly). SVG is a first-class vector format that browsers include in the print pipeline
without any additional handling. There is no rendering race condition because the chart is already
rendered in the DOM when `window.print()` is called — the browser is not asked to re-execute
JavaScript during printing.

This is the key advantage over server-side Chromium: when the user triggers print, the charts are
already rendered and ready. ChromicPDF's `wait_for` mechanism exists precisely because headless
Chrome has to render the page from scratch and wait for async JS to complete. The browser print
path skips all of that.

### The "Print / Save as PDF" Button

The button should be a pure LiveView JS command. Do not use a Phoenix event that round-trips to
the server — there is nothing the server needs to do.

```heex
<%!-- In MetricFlowWeb.AiLive.ReportGenerator or the report show template --%>
<button
  id="print-report-btn"
  phx-click={JS.dispatch("mf:print")}
  class="btn btn-outline btn-sm gap-2"
>
  <.icon name="hero-printer" class="w-4 h-4" />
  Print / Save as PDF
</button>
```

Register the event listener in `app.js`. Do not write an inline `<script>` tag — per project
guidelines, all JS goes in `assets/js/`:

```javascript
// assets/js/app.js — add after the liveSocket setup
window.addEventListener("mf:print", () => window.print())
```

This wires the dispatched CustomEvent to `window.print()` without any LiveView server
round-trip.

### The VegaChart Hook: Setting data-ready

The existing `VegaChart` hook (established in the charting decision) should set a `data-ready`
attribute after each chart finishes rendering. This attribute serves two purposes:

1. It allows JavaScript to know when all charts are visible before triggering print.
2. It is the gate ChromicPDF's `wait_for` will poll in Phase 2.

```javascript
// assets/js/hooks/vega_chart.js
import vegaEmbed from "vega-embed"

const VegaChart = {
  mounted() {
    const spec = JSON.parse(this.el.dataset.spec)

    vegaEmbed(this.el, spec, { actions: false, renderer: "svg" })
      .then(result => {
        this.view = result.view
        // Mark this chart element as rendered. Phase 2 ChromicPDF gates on this.
        this.el.setAttribute("data-ready", "true")
      })
      .catch(console.error)

    this.handleEvent(`chart:update:${this.el.id}`, ({ spec }) => {
      this.el.removeAttribute("data-ready")
      vegaEmbed(this.el, spec, { actions: false, renderer: "svg" })
        .then(result => {
          this.view = result.view
          this.el.setAttribute("data-ready", "true")
        })
        .catch(console.error)
    })
  },

  destroyed() {
    if (this.view) this.view.finalize()
  }
}

export default VegaChart
```

For the browser print path, if you want to wait for all charts to be ready before printing (to
avoid printing a page where charts are still loading), you can gate the dispatch:

```javascript
// assets/js/app.js
window.addEventListener("mf:print", () => {
  const charts = document.querySelectorAll("[data-vega-chart]")
  const allReady = Array.from(charts).every(el => el.hasAttribute("data-ready"))

  if (allReady) {
    window.print()
  } else {
    // Poll until ready, then print. Vega renders in <200ms for typical specs.
    const interval = setInterval(() => {
      const allNowReady = Array.from(document.querySelectorAll("[data-vega-chart]"))
        .every(el => el.hasAttribute("data-ready"))
      if (allNowReady) {
        clearInterval(interval)
        window.print()
      }
    }, 100)
  }
})
```

Tag each chart container with `data-vega-chart` to make them queryable:

```heex
<div id={"chart-wrapper-#{@viz.id}"} data-vega-chart phx-hook="VegaChart">
  <div
    id={"chart-#{@viz.id}"}
    phx-update="ignore"
    data-spec={Jason.encode!(@viz.vega_spec)}
  ></div>
</div>
```

---

## Print-Friendly CSS for Vega-Lite SVG Charts

All `@media print` rules go in `assets/css/app.css`. Per project guidelines, do not use `@apply`
in raw CSS. Write Tailwind utilities in templates and raw CSS properties in the stylesheet.

```css
/* assets/css/app.css — add at the end of the file */

@media print {
  /* Hide navigation chrome, action buttons, and sidebar */
  nav,
  aside,
  [data-print-hide],
  #print-report-btn,
  #download-csv-btn {
    display: none !important;
  }

  /* Remove page margins and background colors that waste ink */
  body {
    background: white;
    color: black;
  }

  /* Prevent chart containers from splitting across page breaks */
  [data-vega-chart] {
    break-inside: avoid;
    page-break-inside: avoid; /* legacy fallback */
  }

  /* Ensure SVG charts render at full width and scale correctly.
     vega-embed SVGs have inline width/height; override for print. */
  [data-vega-chart] svg {
    width: 100% !important;
    max-width: 100% !important;
    height: auto !important;
  }

  /* Give narrative text sections room to breathe */
  .report-section {
    break-inside: avoid;
    page-break-inside: avoid;
    margin-bottom: 1.5rem;
  }

  /* Report title on its own page header */
  .report-title {
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
  }

  /* Force page break before each major report section if desired */
  .report-page-break-before {
    break-before: page;
    page-break-before: always;
  }

  /* Ensure links are visible in printed output */
  a[href]::after {
    content: " (" attr(href) ")";
    font-size: 0.75rem;
    color: #555;
  }

  /* Suppress link annotations for icon-only or UI links */
  a[data-print-no-href]::after {
    content: none;
  }
}
```

### HEEx Annotations for Print Visibility

Tag elements that should be hidden in print with `data-print-hide`:

```heex
<%!-- Action toolbar — hidden in print --%>
<div class="flex gap-2 items-center" data-print-hide>
  <button id="print-report-btn" phx-click={JS.dispatch("mf:print")} class="btn btn-outline btn-sm">
    <.icon name="hero-printer" class="w-4 h-4" />
    Print / Save as PDF
  </button>
  <.link
    id="download-csv-btn"
    href={~p"/reports/#{@report.id}/export.csv"}
    class="btn btn-outline btn-sm"
  >
    <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
    Download CSV
  </.link>
</div>
```

---

## Phase 1: CSV Export

### No New Dependencies Required

The metric rows are already Elixir maps. CSV serialization requires only:

- Building a header row from the map keys
- Encoding each row's values as comma-separated strings
- Setting the correct response headers

NimbleCSV is not in `mix.exs` and adding it is optional. A manual builder handles this use case
without any new dependency.

### Manual CSV Builder Module

```elixir
# lib/metric_flow/reports/csv_export.ex
defmodule MetricFlow.Reports.CsvExport do
  @moduledoc """
  Serializes a list of metric row maps to CSV-encoded binary.

  All keys must be consistent across rows. The first row's keys determine the header order.
  Values are coerced to strings; nil becomes an empty cell.
  """

  @doc """
  Encodes a list of maps to a CSV binary with a header row.

  ## Example

      iex> rows = [%{date: ~D[2026-01-01], sessions: 1200, revenue: 4500.00}]
      iex> MetricFlow.Reports.CsvExport.encode(rows)
      "date,sessions,revenue\\n2026-01-01,1200,4500.0\\n"
  """
  @spec encode([map()]) :: binary()
  def encode([]), do: ""

  def encode([first | _rest] = rows) do
    headers = Map.keys(first) |> Enum.map(&to_string/1)

    header_line = Enum.join(headers, ",")

    data_lines =
      Enum.map(rows, fn row ->
        headers
        |> Enum.map(fn key -> row |> Map.get(String.to_existing_atom(key)) |> encode_value() end)
        |> Enum.join(",")
      end)

    Enum.join([header_line | data_lines], "\n") <> "\n"
  end

  defp encode_value(nil), do: ""
  defp encode_value(%Date{} = d), do: Date.to_iso8601(d)
  defp encode_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_value(v) when is_binary(v), do: escape_csv(v)
  defp encode_value(v), do: to_string(v)

  # Wrap fields containing commas, quotes, or newlines in double quotes.
  # Escape embedded double quotes by doubling them (RFC 4180).
  defp escape_csv(s) do
    if String.contains?(s, [",", "\"", "\n"]) do
      ~s("#{String.replace(s, "\"", "\"\"")}")
    else
      s
    end
  end
end
```

### CSV Controller Endpoint

The CSV download is a standard controller action, not a LiveView. It lives inside the
`:require_authenticated_user` plug scope since reports belong to an authenticated user.

```elixir
# lib/metric_flow_web/controllers/report_export_controller.ex
defmodule MetricFlowWeb.ReportExportController do
  use MetricFlowWeb, :controller

  alias MetricFlow.Reports
  alias MetricFlow.Reports.CsvExport

  @doc """
  GET /reports/:id/export.csv

  Streams metric data for the given report as a CSV download.
  """
  def csv(conn, %{"id" => report_id}) do
    scope = conn.assigns.current_scope

    case Reports.get_report(scope, report_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Report not found")

      report ->
        rows = Reports.list_metric_rows_for_report(scope, report)
        csv_data = CsvExport.encode(rows)

        filename = "report-#{report.id}-#{Date.utc_today()}.csv"

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, csv_data)
    end
  end
end
```

### Router Registration

Add the export route inside the existing `:require_authenticated_user` scope in `router.ex`:

```elixir
# lib/metric_flow_web/router.ex
scope "/", MetricFlowWeb do
  pipe_through [:browser, :require_authenticated_user]

  # ... existing routes ...

  get "/reports/:id/export.csv", ReportExportController, :csv
end
```

This keeps the controller inside the existing authenticated scope. `current_scope` is available
to the controller via `conn.assigns.current_scope` because the browser pipeline runs
`:fetch_current_scope_for_user` before `:require_authenticated_user`.

### NimbleCSV Alternative (Optional)

If the data includes complex string fields (user-generated content with embedded commas and
quotes), NimbleCSV handles RFC 4180 escaping more robustly than the manual builder above. To use
it:

```elixir
# mix.exs — add to deps
{:nimble_csv, "~> 1.2"}
```

```elixir
# Define the parser/dumper once, conventionally at the top of the export module
NimbleCSV.define(MetricFlow.Reports.CSV, separator: ",", escape: "\"")

# Usage in the export function
defp encode_with_nimble(rows) do
  headers = Map.keys(hd(rows)) |> Enum.map(&to_string/1)

  data =
    Enum.map(rows, fn row ->
      Enum.map(headers, fn k -> row[String.to_existing_atom(k)] |> to_string() end)
    end)

  [headers | data]
  |> MetricFlow.Reports.CSV.dump_to_iodata()
  |> IO.iodata_to_binary()
end
```

The manual builder in this document is sufficient for Phase 1. NimbleCSV is the recommended
upgrade if user-generated text content (report narrative, metric names) appears in CSV rows.

---

## Phase 2: ChromicPDF Upgrade Path

This section documents what must be true before adding ChromicPDF. Do not begin Phase 2 until all
prerequisites are met.

### Prerequisites Checklist

- [ ] Report HTML template is finalized: layout, typography, narrative sections, chart positions.
      Changes to the template after ChromicPDF is added require retesting all PDF output.
- [ ] Confirmed user demand for server-generated PDF. Browser print may be sufficient for the
      majority of users — validate with real usage before accepting the operational cost.
- [ ] Fly.io machine upgraded from `shared-cpu-1x` (256–512 MB) to at least `shared-cpu-2x`
      (512 MB or 1 GB). Chromium requires 150–300 MB of RAM per concurrent headless session.
      On a 256 MB machine, one PDF render can trigger an OOM kill.
- [ ] Report is accessible at a dedicated server-rendered URL (not a LiveView socket route).
      ChromicPDF fetches a URL with an HTTP GET; it cannot authenticate via a LiveView WebSocket.
      The recommended pattern is a dedicated controller action that renders the report as plain
      HTML (no layout chrome) using a Phoenix HTML template.
- [ ] The `VegaChart` hook sets `data-ready="true"` on each chart element after rendering.
      This attribute is the signal ChromicPDF polls before triggering `printToPDF`. The hook
      code in this document already does this.

### Adding ChromicPDF

```elixir
# mix.exs
{:chromic_pdf, "~> 1.17"}
```

Add ChromicPDF to the application supervision tree:

```elixir
# lib/metric_flow/application.ex
children = [
  # ... existing children ...
  {ChromicPDF, chromic_pdf_opts()}
]

defp chromic_pdf_opts do
  [
    # Required for containers (Docker/Fly.io). Chrome's sandbox requires
    # kernel namespacing features that are not available in unprivileged containers.
    no_sandbox: true,
    # Pool of Chrome sessions. Start conservatively; one concurrent render is safe
    # on a 512 MB machine. Increase when machine RAM is upgraded.
    session_pool: [size: 2],
    # Timeout for a single render. PDFs with many charts can take 3–5 seconds.
    checkout_timeout: 30_000
  ]
end
```

### wait_for Pattern for Vega-Lite Charts

ChromicPDF's `wait_for` option polls a DOM selector for a specific attribute value before it
signals Chrome to print. Because Vega-Lite renders asynchronously after the page loads, this is
the mechanism that prevents blank charts in server-generated PDFs.

The `VegaChart` hook already sets `data-ready="true"` per chart. To gate on all charts being
ready, use a sentinel element that the report LiveView (or controller) updates once all charts
have signaled readiness:

```javascript
// assets/js/app.js — track how many charts have rendered
window.addEventListener("phx:chart-ready", () => {
  const total = document.querySelectorAll("[data-vega-chart]").length
  const ready = document.querySelectorAll("[data-vega-chart][data-ready]").length
  if (ready === total && total > 0) {
    document.body.setAttribute("data-all-charts-ready", "true")
  }
})
```

```javascript
// assets/js/hooks/vega_chart.js — dispatch the event after setting data-ready
vegaEmbed(this.el, spec, { actions: false, renderer: "svg" })
  .then(result => {
    this.view = result.view
    this.el.setAttribute("data-ready", "true")
    window.dispatchEvent(new CustomEvent("phx:chart-ready"))
  })
```

ChromicPDF then waits for the sentinel:

```elixir
defmodule MetricFlow.Reports.PdfExport do
  @moduledoc """
  Server-side PDF generation via ChromicPDF.
  Only used in Phase 2 once the report template is finalized.
  """

  @doc """
  Generates a PDF for the given report URL and returns the binary.

  `report_url` must be a fully-qualified internal URL that ChromicPDF can fetch.
  Use an internal server URL, not a LiveView route.

  ## Example

      {:ok, pdf_binary} = PdfExport.generate("http://localhost:4000/reports/42/print")
  """
  @spec generate(String.t()) :: {:ok, binary()} | {:error, term()}
  def generate(report_url) do
    ChromicPDF.print_to_pdf(
      {:url, report_url},
      wait_for: %{
        selector: "body",
        attribute: "data-all-charts-ready"
      },
      print_to_pdf: %{
        printBackground: true,
        marginTop: 0.4,
        marginBottom: 0.4,
        marginLeft: 0.4,
        marginRight: 0.4,
        paperWidth: 8.5,
        paperHeight: 11.0
      }
    )
  end
end
```

### Dedicated Print Route

ChromicPDF fetches a URL. That URL should render the report as bare HTML — no navigation sidebar,
no LiveView socket, no action buttons. This is a standard Phoenix controller action:

```elixir
# lib/metric_flow_web/controllers/report_export_controller.ex
# Phase 2 addition to the existing controller

def print(conn, %{"id" => report_id}) do
  scope = conn.assigns.current_scope

  case Reports.get_report(scope, report_id) do
    nil ->
      conn |> put_status(:not_found) |> text("Report not found")

    report ->
      visualizations = Reports.list_visualizations_for_report(scope, report)
      render(conn, :print, report: report, visualizations: visualizations)
  end
end
```

```elixir
# router.ex — inside :require_authenticated_user scope
get "/reports/:id/print", ReportExportController, :print
get "/reports/:id/export.pdf", ReportExportController, :pdf
```

The `:print` template renders with no layout chrome. The `:pdf` action calls `PdfExport.generate/1`
with the internal print URL and sends the binary:

```elixir
def pdf(conn, %{"id" => report_id}) do
  scope = conn.assigns.current_scope

  case Reports.get_report(scope, report_id) do
    nil ->
      conn |> put_status(:not_found) |> text("Report not found")

    report ->
      print_url = url(~p"/reports/#{report.id}/print")

      case MetricFlow.Reports.PdfExport.generate(print_url) do
        {:ok, pdf_binary} ->
          filename = "report-#{report.id}-#{Date.utc_today()}.pdf"

          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
          |> send_resp(200, pdf_binary)

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> text("PDF generation failed: #{inspect(reason)}")
      end
  end
end
```

### Dockerfile Changes for Phase 2

Add Chromium and font packages to the Dockerfile generated by `fly launch`. These go after the
Elixir/OTP installation steps and before the release build:

```dockerfile
# Install Chromium for ChromicPDF headless PDF rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-sandbox \
    fonts-liberation \
    fonts-dejavu-core \
    libatk-bridge2.0-0 \
    libcups2 \
    libgtk-3-0 \
    libxss1 \
    && rm -rf /var/lib/apt/lists/*
```

This adds approximately 350–400 MB to the Docker image. Plan for a Docker image over 600 MB total.

Note that `no_sandbox: true` is required in `chromic_pdf_opts/0` — this is not a security
regression unique to the project. It is a documented, expected requirement for all ChromicPDF
deployments on container platforms that lack Linux namespace capabilities. See the ChromicPDF
documentation for the security rationale.

---

## Report Data Model: Saving and Loading

The report data model is not yet defined in a spec file. Based on the decision record, each saved
report should contain at minimum:

```elixir
# Anticipated schema — not yet implemented
schema "reports" do
  field :title, :string
  field :narrative_text, :string
  field :generated_at, :utc_datetime

  # The Vega-Lite spec for each chart in the report.
  # Stored as a list of vega_spec maps alongside positional/label metadata.
  embeds_many :sections, ReportSection do
    field :heading, :string
    field :body_text, :string
    # vega_spec is nil for text-only sections
    field :vega_spec, :map
    field :position, :integer
  end

  belongs_to :account, MetricFlow.Accounts.Account
  timestamps()
end
```

The `vega_spec` field follows the same pattern as `MetricFlow.Dashboards.Visualization.vega_spec`.
The `VegaChart` hook renders it identically — no special report-specific chart code is needed.

---

## Report LiveView Rendering Pattern

The report generator LiveView renders charts using the same `VegaChart` hook established for
dashboards. The outer div carries the hook; the inner div has `phx-update="ignore"` to prevent
LiveView from destroying the rendered SVG on socket updates.

```heex
<%!-- In MetricFlowWeb.AiLive.ReportGenerator — report section with chart --%>
<%= for section <- @report.sections do %>
  <div class="report-section">
    <%= if section.heading do %>
      <h2 class="text-xl font-semibold mb-2">{section.heading}</h2>
    <% end %>

    <%= if section.body_text do %>
      <p class="text-base text-base-content mb-4">{section.body_text}</p>
    <% end %>

    <%= if section.vega_spec do %>
      <div
        id={"chart-wrapper-section-#{section.position}"}
        data-vega-chart
        phx-hook="VegaChart"
        class="w-full"
      >
        <div
          id={"chart-section-#{section.position}"}
          phx-update="ignore"
          data-spec={Jason.encode!(section.vega_spec)}
        ></div>
      </div>
    <% end %>
  </div>
<% end %>
```

---

## Testing CSV Export

The CSV controller action is testable with `Phoenix.ConnTest` without a browser. The `CsvExport`
module is pure functional code testable with `ExUnit.Case`:

```elixir
# test/metric_flow/reports/csv_export_test.exs
defmodule MetricFlow.Reports.CsvExportTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Reports.CsvExport

  describe "encode/1" do
    test "returns empty string for empty list" do
      assert CsvExport.encode([]) == ""
    end

    test "produces header and data rows" do
      rows = [%{date: ~D[2026-01-01], sessions: 1200}]
      csv = CsvExport.encode(rows)

      assert csv =~ "date,sessions"
      assert csv =~ "2026-01-01,1200"
    end

    test "escapes commas in string values" do
      rows = [%{name: "Smith, John", value: 42}]
      csv = CsvExport.encode(rows)

      assert csv =~ ~s("Smith, John")
    end

    test "encodes nil values as empty cells" do
      rows = [%{date: ~D[2026-01-01], revenue: nil}]
      csv = CsvExport.encode(rows)

      assert csv =~ "2026-01-01,"
    end
  end
end
```

The controller test verifies the response headers and content type:

```elixir
# test/metric_flow_web/controllers/report_export_controller_test.exs
defmodule MetricFlowWeb.ReportExportControllerTest do
  use MetricFlowWeb.ConnCase

  setup :register_and_log_in_user

  describe "GET /reports/:id/export.csv" do
    test "returns csv with correct headers for own report", %{conn: conn, scope: scope} do
      report = insert_report_fixture(scope)

      conn = get(conn, ~p"/reports/#{report.id}/export.csv")

      assert response_content_type(conn, :csv) =~ "text/csv"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment"
      assert response(conn, 200) =~ ","
    end

    test "returns 404 for a report not owned by current user", %{conn: conn} do
      other_report = insert_report_fixture_for_other_user()

      conn = get(conn, ~p"/reports/#{other_report.id}/export.csv")

      assert response(conn, 404)
    end
  end
end
```

---

## Summary: What to Build in Phase 1

| Task | Location | Notes |
|---|---|---|
| Add `mf:print` event listener | `assets/js/app.js` | Calls `window.print()` |
| Add `data-ready` to `VegaChart` hook | `assets/js/hooks/vega_chart.js` | After `vegaEmbed` resolves |
| Add `@media print` CSS | `assets/css/app.css` | Hide nav, avoid chart breaks |
| "Print / Save as PDF" button | Report template | `phx-click={JS.dispatch("mf:print")}` |
| `CsvExport` module | `lib/metric_flow/reports/csv_export.ex` | No deps needed |
| `ReportExportController` with `csv/2` | `lib/metric_flow_web/controllers/` | Inside authenticated scope |
| Router: `GET /reports/:id/export.csv` | `lib/metric_flow_web/router.ex` | In `:require_authenticated_user` |
| "Download CSV" link | Report template | `href={~p"/reports/#{@report.id}/export.csv"}` |

Phase 2 (ChromicPDF) begins only after the report template is finalized and user demand for
server PDF is confirmed. See the prerequisites checklist in the Phase 2 section above.
