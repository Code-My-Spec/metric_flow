# Report Export

**Status:** Proposed
**Date:** 2026-02-21

## Context

MetricFlow has three user stories that touch report output:

- "Create and Save Custom Reports" — users build and persist reports
- "LLM-Generated Custom Reports" — `MetricFlow.Ai.ReportGenerator` produces Vega-Lite specs from natural language
- "View and Navigate Saved Reports" — users browse saved reports in the UI

Each report is a combination of Vega-Lite chart visualizations (stored as JSON specs in the
`Visualization` schema's `vega_spec` field) and textual analysis. The charting decision established
that Vega-Lite specs are the data model's lingua franca: the LLM generates them, the database stores
them, and `vega-embed` renders them client-side in the browser.

The question is whether reports also need to be exported as downloadable PDFs, and if so, what
mechanism should produce those PDFs.

The core technical constraint is that Vega-Lite charts require a JavaScript runtime to render.
There is no pure-Elixir Vega-Lite renderer. Any server-side PDF path must either:

1. Run a headless browser to execute `vega-embed` and capture the rendered output, or
2. Invoke a purpose-built Vega-Lite-to-image CLI tool to rasterize each chart spec, then
   assemble those images into a document, or
3. Avoid server-side PDF generation entirely and rely on the browser's native print capability.

The project deploys to Fly.io on lightweight VMs (see `deployment.md`). Adding large binary
dependencies — Chromium is ~300 MB, Typst is ~15 MB, vl-convert is ~32 MB — affects Docker image
size, cold-start time, and memory headroom on `shared-cpu-1x` machines with 256–512 MB RAM.

---

## Options Considered

### Option A: ChromicPDF (headless Chromium)

ChromicPDF (v1.17.0, August 2024, ~828k all-time Hex downloads) is the most widely adopted
Elixir PDF library. It communicates directly with Chrome's DevTools API over pipes without
requiring Node.js or Puppeteer.

Because it launches a real browser, it can render any HTML page — including Vega-Lite charts
embedded via `vega-embed`. ChromicPDF provides a `wait_for` option that polls a DOM element for
a specific attribute before triggering `printToPDF`, which allows the application to signal
"charts are done rendering" from within the vega-embed callback:

```javascript
// Set a marker when all charts have finished rendering
vegaEmbed(el, spec).then(result => {
  this.view = result.view
  el.setAttribute("data-ready", "true")
})
```

```elixir
ChromicPDF.print_to_pdf(
  {:url, report_url},
  wait_for: %{selector: "[data-ready]", attribute: "data-ready"},
  print_to_pdf: %{printBackground: true}
)
```

However, Chromium is a ~300 MB binary. Installing it inside a Fly.io Docker container requires
adding Chromium plus font packages to the Dockerfile (approximately 400–500 MB of extra image
layers). Fly.io community threads report that Chrome does not run in its default sandbox mode
inside containers, so `no_sandbox: true` must be passed to ChromicPDF — this is a known
configuration requirement, not a showstopper. Memory usage per headless Chrome session is
significant (typically 150–300 MB per concurrent render), which is a concern on the 256–512 MB
machines targeted for early-stage deployment.

ChromicPDF maintains a session pool (backed by `NimblePool`). Pool sizing and checkout timeouts
must be tuned to avoid timeout errors under concurrent report export load.

**Pros:**
- Renders any HTML faithfully, including Vega-Lite charts, Tailwind CSS, custom fonts
- The `wait_for` mechanism handles async JS rendering reliably
- Mature library with strong community adoption and active maintenance
- PDF/A support via optional Ghostscript integration
- Headers, footers, page numbers via Chrome DevTools `printToPDF` options

**Cons:**
- Chromium adds ~300–400 MB to the Docker image; total image size likely exceeds 600 MB
- High memory usage per concurrent render; risky on 256–512 MB Fly.io machines at early scale
- Chrome sandbox restrictions in containers require `no_sandbox: true`
- Chromium installation on Fly.io has had documented friction (community reports of issues)
- ChromicPDF starts a long-running Chrome process in the application supervision tree — adds
  operational complexity and a new failure mode

---

### Option B: Pure Elixir PDF (prawn_ex / elixir-pdf)

Two pure-Elixir libraries exist for PDF generation without external binary dependencies:

- **prawn_ex** (Prawn-style declarative PDF, no Chrome or HTML, tables, charts from data)
- **elixir-pdf** (lower-level, functional for basic needs per community reports)

Neither library can render Vega-Lite specs. Vega-Lite requires a JavaScript runtime to compile
and render the declarative grammar into visual marks. Using these libraries would require either:
(a) abandoning Vega-Lite output in reports entirely and building bespoke chart rendering in
Elixir, or (b) maintaining a parallel charting implementation just for PDF output.

Both approaches contradict the core architecture decision: Vega-Lite is the shared format between
the LLM generator, the database schema, and the rendering layer. Any deviation breaks that chain.

**Pros:**
- No external binary dependencies; minimal Docker image impact
- No memory or process supervision concerns

**Cons:**
- Cannot render Vega-Lite specs — a fundamental incompatibility with the architecture
- Would require duplicating charting logic in a different format just for PDF
- `prawn_ex` has very low adoption (niche library); `elixir-pdf` is limited in capability
- Eliminates the value of storing Vega-Lite specs in the first place

---

### Option C: Typst via CLI

Typst is a modern Rust-based typesetting system. It compiles `.typ` markup files into PDF. A
typical Linux x86_64 binary is approximately 15 MB. Integration from Elixir uses `System.cmd/3`:

```elixir
# Render an EEx template to a .typ file, then compile it
with {:ok, content} <- render_typst_template(report),
     tmp_file <- write_temp_file(content, ".typ"),
     {_output, 0} <- System.cmd("typst", ["compile", tmp_file, output_path]) do
  {:ok, output_path}
end
```

Typst produces high-quality typeset documents and has been adopted by Elixir Forum community
members for structured reports (the "PDF generation without Chromium" thread from late 2024
explicitly named it as the chosen solution in one case).

However, Typst does not consume Vega-Lite specs. Charts would need to be pre-rendered to SVG
or PNG before being embedded. This means either:
(a) using `vl-convert` (see Option D) to rasterize each chart spec to SVG/PNG first, then
    embedding those images in the Typst document, or
(b) writing a Typst-native charting approach, which has no shared code with the existing stack.

Path (a) turns this into a two-step pipeline: `vl-convert` for charts, then Typst for layout.
This adds complexity without a clear quality advantage over ChromicPDF for this use case.
Typst excels at structured typographic documents (academic papers, invoices, proposals) rather
than marketing analytics reports with embedded interactive-style charts.

**Pros:**
- Small binary (~15 MB) — minimal Docker image and memory impact
- No sandboxing concerns; runs as a simple child process
- Excellent typographic output for text-heavy structured documents
- Self-contained Rust binary with no runtime dependencies

**Cons:**
- Cannot natively render Vega-Lite specs; requires a pre-render step (adds complexity)
- Requires learning Typst's markup language and maintaining `.typ` templates
- Two-process pipeline (vl-convert + typst) adds error surface and latency
- Better suited to structured typographic documents than data dashboards

---

### Option D: vl-convert CLI for chart rasterization

`vl-convert` (maintained by the Vega team, v1.9.0 released January 2026, v2.0.0-rc1 available)
is a self-contained Rust binary that converts Vega-Lite JSON specs to SVG, PNG, or PDF using an
embedded V8/Deno runtime. It does not require Node.js or a browser. The Linux x86_64 binary is
approximately 31 MB.

```elixir
# Convert a Vega-Lite spec to SVG via vl-convert CLI
defp render_chart_to_svg(vega_spec) do
  spec_json = Jason.encode!(vega_spec)
  tmp_spec = write_temp_file(spec_json, ".json")
  tmp_svg = Briefly.create!(extname: ".svg")
  {_, 0} = System.cmd("vl-convert", ["vl2svg", "-i", tmp_spec, "-o", tmp_svg])
  File.read!(tmp_svg)
end
```

This produces vector SVG output that can be embedded in HTML or a document template. However,
`vl-convert` alone only renders individual charts. A full report PDF still requires assembling
multiple charts plus text narrative into a paginated document, which needs another tool
(Typst, WeasyPrint, or HTML-to-PDF).

`vl-convert` is best understood as a chart rasterization step within a larger pipeline, not as
a complete PDF solution on its own.

**Pros:**
- Official Vega team tool — guaranteed compatibility with Vega-Lite 6.x specs
- Self-contained binary (~31 MB), no Node.js or browser required
- Actively maintained: v1.9.0 January 2026, v2.0.0-rc1 February 2026
- Produces SVG (vector) output suitable for embedding in PDF at any scale
- Pre-built Linux x86_64 binaries available on GitHub releases

**Cons:**
- Only handles chart rendering; does not assemble a complete multi-page PDF document
- Requires composition with a second tool for page layout (adds pipeline complexity)
- `System.cmd` invocation per chart is sequential; a report with five charts requires five
  subprocess calls
- Adding both `vl-convert` and a layout tool to the Dockerfile is non-trivial

---

### Option E: Phased approach — save specs and render in-browser first, defer server PDF

Deliver the save/view report stories using only client-side rendering (no server-side PDF
generation) in Phase 1. Add PDF export in Phase 2 once the report data model and UI are stable.

Phase 1 deliverables:
- Reports saved as `{vega_spec, narrative_text}` records in the database
- Reports rendered in the browser via `vega-embed` (already decided for dashboards)
- Browser print (`window.print()` + `@media print` CSS) produces a reasonable PDF for early users
- CSV export of the underlying metric data as a lightweight download alternative

Phase 2 (deferred):
- Evaluate server-side PDF generation once the report template is stable
- At that point, ChromicPDF becomes lower risk because: (a) the report HTML is finalized,
  (b) actual user demand for PDF export is confirmed, (c) machine sizing can be revisited

The browser's built-in print pipeline already handles Vega-Lite charts because `vega-embed`
renders SVG natively, and `@media print` CSS can hide navigation chrome, adjust layout, and
force page breaks. This requires no new dependencies and no Fly.io deployment changes.

**Pros:**
- Zero deployment complexity added in Phase 1
- No Docker image size increase, no memory pressure
- Unblocks the report save/view stories immediately
- Browser print is surprisingly capable for SVG charts (no rendering race conditions)
- CSV export satisfies data-download needs without requiring PDF at all
- Deferral avoids premature commitment before report layout is finalized
- Reduces scope for current sprint while the data model is still evolving

**Cons:**
- Users cannot generate a polished server-produced PDF from Phase 1
- Browser print output quality depends on print CSS work and browser behavior
- Defers a user-facing feature; some users may expect PDF from day one
- Phase 2 decision is pushed into the future (but documented here as the next step)

---

## Decision

**Adopt Option E: phased approach. Build report save and client-side render in Phase 1; defer
server-side PDF export to Phase 2.**

The reasoning:

1. **Report data model is not stable yet.** The `ReportGenerator` spec (`docs/spec/metric_flow/ai/report_generator.spec.md`) has no functions defined. The database schema for reports, the narrative text structure, and the exact page layout are all undecided. Committing to a specific PDF pipeline now means redesigning the pipeline when the report format changes.

2. **Server PDF with Vega-Lite charts is genuinely hard.** Every server-side option has a significant operational cost:
   - ChromicPDF requires Chromium (~300–400 MB) in the Docker image and carries memory risk on early Fly.io machines.
   - vl-convert + Typst is a two-process pipeline with its own failure modes and requires learning Typst markup.
   - Pure Elixir libraries cannot render Vega-Lite at all.

   None of these costs are unreasonable in the long run, but they are front-loaded costs for a feature whose exact requirements are not yet known.

3. **The browser print path is viable for early use.** Because `vega-embed` renders Vega-Lite to SVG natively, and SVG prints faithfully, `@media print` CSS plus `window.print()` produces usable PDFs without server involvement. This is not a throwaway placeholder — many analytics tools use this pattern indefinitely.

4. **CSV export addresses the data download need.** Users who want to act on report data can download the underlying metrics as CSV. This is simpler to implement and has clearer utility than PDF for data analysis workflows.

5. **When Phase 2 lands, ChromicPDF is the right choice.** Once the report template is stable, ChromicPDF's `wait_for` mechanism is the cleanest approach because it renders the exact HTML the user sees — the same Tailwind styles, the same Vega-Lite charts, the same layout. No translation layer, no additional chart rendering tool. By Phase 2, Fly.io machine sizing can be upgraded if needed, and the operational cost is easier to justify against confirmed user demand.

---

## Consequences

**Phase 1 actions (unblock report save/view stories):**

- Implement report save as `{vega_spec, narrative_text}` records; no PDF endpoint needed.
- Render reports in `MetricFlowWeb.AiLive.ReportGenerator` using the same `VegaChart` hook
  pattern established for dashboards.
- Add `@media print` CSS to the report layout template: hide navigation sidebar, remove
  action buttons, allow charts to break across pages cleanly with `break-inside: avoid`.
- Add a "Download CSV" button that exports the metric data rows used in the report.
- Add a "Print / Save as PDF" button that calls `window.print()` via a LiveView JS command.

**Phase 2 prerequisites (before implementing server PDF):**

- Report HTML template must be finalized (layout, fonts, narrative sections, chart positions).
- Confirm actual user demand for server-generated PDF (browser print may suffice).
- If proceeding, add ChromicPDF to `mix.exs` and add Chromium to the Dockerfile. Upgrade
  the Fly.io machine from `shared-cpu-1x` to at least `shared-cpu-2x` with 512 MB or 1 GB
  to absorb Chromium memory overhead.
- The vega-embed `mounted()` callback in `VegaChart` hook should set `data-ready="true"` on
  the chart element once rendering completes, so ChromicPDF's `wait_for` can gate on it.
- Serve the report at a dedicated server-rendered URL (not a LiveView route) that ChromicPDF
  can fetch internally — this avoids WebSocket authentication complications with headless Chrome.

**Trade-offs accepted:**

- Phase 1 users receive browser-print quality PDF, not a server-generated polished PDF.
- The PDF export feature is explicitly deferred; a follow-up decision record should be written
  when Phase 2 is scheduled.
- The `vl-convert` and Typst options are not recommended for this project. `vl-convert` is
  a useful chart rasterization primitive but not a complete PDF solution. Typst is better
  suited to structured typographic documents than marketing analytics dashboards.

**CSV export implementation note:**

CSV export does not require any new Hex dependencies. The underlying metric rows are already
Elixir maps; `NimbleCSV` (or a simple manual CSV builder) can serialize them. Serve the file
from a standard Phoenix controller action with `content-type: text/csv` and
`content-disposition: attachment; filename="report.csv"`.
