defmodule MetricFlow.Check.Warning.MetricFlowSpexDenies do
  use Credo.Check,
    id: "METRIC0001",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Whole-module bypasses are not allowed in BDD spec files (`_spex.exs`).

      Specs drive the application the way a user does — over HTTP or through
      LiveView — and may reach application state only through
      `MetricFlowSpex.Fixtures`. Calling a domain context directly, reading
      the real filesystem, or shelling out to an external program all prove
      the wrong thing: that the code works when driven from inside, not that
      the user sees the intended outcome.

      Denied whole modules:

      - `File`, `:file` — specs run against the in-memory environment; a
        real-disk read silently bypasses it.
      - `Port` — talks to external programs; use a cassette instead.
      - `MetricFlow.Repo` — direct DB reads bypass the public surface.
      - Every `MetricFlow.<Context>` — domain contexts specs must reach only
        through the web layer, never by calling the context function that
        would produce the same effect.
      """
    ]

  @denied_modules [
    [:File],
    [:Port],
    [:MetricFlow, :Repo],
    [:MetricFlow, :Accounts],
    [:MetricFlow, :Agencies],
    [:MetricFlow, :Ai],
    [:MetricFlow, :Billing],
    [:MetricFlow, :Correlations],
    [:MetricFlow, :Dashboards],
    [:MetricFlow, :DataSync],
    [:MetricFlow, :Integrations],
    [:MetricFlow, :Invitations],
    [:MetricFlow, :Metrics],
    [:MetricFlow, :Reviews],
    [:MetricFlow, :Stories]
  ]

  @denied_atom_modules [:file]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    if String.ends_with?(filename, "_spex.exs") do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    else
      []
    end
  end

  # Module.function(...) — e.g. MetricFlow.Repo.get!(...), File.read!(...)
  defp walk({{:., meta, [{:__aliases__, _, mod_parts}, fun]}, _, _args} = ast, ctx) do
    if mod_parts in @denied_modules do
      {ast, put_issue(ctx, issue_for(ctx, meta, Enum.join(mod_parts, ".") <> "." <> to_string(fun)))}
    else
      {ast, ctx}
    end
  end

  # :atom_module.function(...) — e.g. :file.read(...)
  defp walk({{:., meta, [atom_mod, fun]}, _, _args} = ast, ctx) when is_atom(atom_mod) do
    if atom_mod in @denied_atom_modules do
      {ast, put_issue(ctx, issue_for(ctx, meta, "#{inspect(atom_mod)}.#{fun}"))}
    else
      {ast, ctx}
    end
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  defp issue_for(issue_meta, meta, trigger) do
    format_issue(
      issue_meta,
      message:
        "`#{trigger}` is a whole-module bypass not allowed in _spex.exs files. Reach state through MetricFlowSpex.Fixtures or the web layer instead.",
      trigger: trigger,
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
