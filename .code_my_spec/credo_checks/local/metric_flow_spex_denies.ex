defmodule MetricFlow.Check.Warning.MetricFlowSpexDenies do
  use Credo.Check,
    id: "METRIC0001",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      BDD spec files (`_spex.exs`) may not reference internal MetricFlow
      contexts, `MetricFlow.Repo`, or real-disk/port I/O directly.

      Specs drive the application the way a user does — through LiveView or
      HTTP — and reach application state only through
      `MetricFlowSpex.Fixtures`, the one sanctioned bridge into app internals.
      Reaching a context or the repo directly bypasses the public surface the
      spec is supposed to prove; reaching the real filesystem or a port
      bypasses the in-memory environment the spec suite runs against.

      Add a narrow function to `MetricFlowSpex.Fixtures` instead, or drive the
      state through the UI.
      """
    ]

  @denied_modules ~w(
    File
    Port
    MetricFlow.Repo
    MetricFlow.Accounts
    MetricFlow.Agencies
    MetricFlow.Ai
    MetricFlow.Billing
    MetricFlow.Correlations
    MetricFlow.Dashboards
    MetricFlow.DataSync
    MetricFlow.Integrations
    MetricFlow.Invitations
    MetricFlow.Metrics
    MetricFlow.Reviews
    MetricFlow.Users
  )

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

  # MetricFlow.Accounts.foo(), alias MetricFlow.Accounts, File.read!(...), Port.open(...)
  defp walk({:__aliases__, meta, parts} = ast, ctx) do
    name = Enum.map_join(parts, ".", &to_string/1)

    if name in @denied_modules do
      {ast, put_issue(ctx, issue_for(ctx, meta, name))}
    else
      {ast, ctx}
    end
  end

  # :file.read_file(...) — the stdlib bypass that has no Elixir alias to catch above
  defp walk({{:., meta, [:file, fun]}, _, _} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, ":file.#{fun}"))}
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  defp issue_for(issue_meta, meta, trigger) do
    format_issue(
      issue_meta,
      message:
        "`#{trigger}` is not allowed in _spex.exs files. Use MetricFlowSpex.Fixtures or drive state through the UI instead.",
      trigger: trigger,
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
