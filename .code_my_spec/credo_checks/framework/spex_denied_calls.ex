defmodule CodeMySpec.Check.Warning.SpexDeniedCalls do
  use Credo.Check,
    id: "CMS0002",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Universal function-level denies for BDD spec files (`_spex.exs`).

      This is the FRAMEWORK template — it ships with the harness and is
      installed verbatim into every project. It carries the function-level
      denies that hold for every project (shell escape, dynamic dispatch,
      VM mutation, dynamic code eval). Project-specific WHOLE-module
      denies (`File`, `Port`, `:file`, and any app contexts the spec
      boundary shouldn't reach) belong in `.code_my_spec/credo_checks/local/`,
      not here.

      Function-level denies (the rest of the module is fine):

      - `System.cmd/2,3`, `System.shell/1,2` — shelling out.
      - `System.halt`, `System.stop`, `System.at_exit`, `System.put_env`,
        `System.delete_env`, `System.restart` — VM/env mutation.
      - `:os.cmd/1` — shelling out via Erlang.
      - `Code.eval_*`, `Code.compile_string`, `Code.compile_quoted`,
        `Code.require_file` — dynamic code evaluation.
      - `Kernel.apply/2,3` — dynamic dispatch escape hatch.

      Whole-module denies are intentionally empty here. The AST scaffolding
      below is wired up so a project-local check can mirror it — see the
      `spex_boundary_ready` workflow for the standard fill-in.

      If a spec needs shell execution or dynamic dispatch to make a
      scenario work, the scenario is almost certainly wrong — re-read
      `.code_my_spec/knowledge/bdd/spex/boundaries.md` before reaching for one of
      these.
      """
    ]

  # Whole-module denies are project-specific. The shipped template leaves
  # these empty by design; fill them in via a project-local check at
  # `.code_my_spec/credo_checks/local/<app>_spex_denies.ex`.
  @denied_whole_modules []
  @denied_whole_erlang_modules []

  @denied_module_functions %{
    System => ~w(cmd shell halt stop at_exit put_env delete_env restart)a,
    Code => ~w(eval_string eval_file eval_quoted compile_string compile_quoted require_file)a
  }

  @denied_erlang_module_functions %{
    os: [:cmd]
  }

  @denied_kernel_functions [{:apply, 2}, {:apply, 3}]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    if String.ends_with?(filename, "_spex.exs") do
      ctx = %{issue_meta: Context.build(source_file, params, __MODULE__), issues: []}
      Credo.Code.prewalk(source_file, &traverse/2, ctx).issues
    else
      []
    end
  end

  # Kernel.apply(...) — explicit alias form.
  defp traverse(
         {{:., _, [{:__aliases__, meta, [:Kernel]}, fun]}, _, args} = ast,
         ctx
       )
       when is_list(args) do
    arity = length(args)

    if {fun, arity} in @denied_kernel_functions do
      {ast, add_issue(ctx, meta, "Kernel.#{fun}/#{arity}")}
    else
      {ast, ctx}
    end
  end

  # Aliased Elixir modules — System.*, Code.*, and (when filled in) File.*, Port.*, ...
  defp traverse(
         {{:., _, [{:__aliases__, meta, module_parts}, fun]}, _, _args} = ast,
         ctx
       ) do
    module = Module.concat(module_parts)

    cond do
      module in @denied_whole_modules ->
        {ast, add_issue(ctx, meta, "#{inspect(module)}.#{fun}")}

      is_list(Map.get(@denied_module_functions, module)) and
          fun in Map.fetch!(@denied_module_functions, module) ->
        {ast, add_issue(ctx, meta, "#{inspect(module)}.#{fun}")}

      true ->
        {ast, ctx}
    end
  end

  # Erlang modules — :os.*, and (when filled in) :file.*, ...
  defp traverse({{:., _, [erl_mod, fun]}, meta, _args} = ast, ctx)
       when is_atom(erl_mod) do
    cond do
      erl_mod in @denied_whole_erlang_modules ->
        {ast, add_issue(ctx, meta, "#{inspect(erl_mod)}.#{fun}")}

      is_list(Map.get(@denied_erlang_module_functions, erl_mod)) and
          fun in Map.fetch!(@denied_erlang_module_functions, erl_mod) ->
        {ast, add_issue(ctx, meta, "#{inspect(erl_mod)}.#{fun}")}

      true ->
        {ast, ctx}
    end
  end

  # Bare `apply(mod, fun, args)` — local/imported form.
  defp traverse({fun, meta, args} = ast, ctx)
       when is_atom(fun) and is_list(args) do
    arity = length(args)

    if {fun, arity} in @denied_kernel_functions do
      {ast, add_issue(ctx, meta, "#{fun}/#{arity}")}
    else
      {ast, ctx}
    end
  end

  defp traverse(ast, ctx), do: {ast, ctx}

  defp add_issue(ctx, meta, trigger) do
    issue =
      format_issue(
        ctx.issue_meta,
        message:
          "Call to `#{trigger}` is denied in _spex.exs files. Specs must act through " <>
            "the public LiveView/hook/MCP surfaces — not shell execution or dynamic dispatch. " <>
            "See .code_my_spec/knowledge/bdd/spex/boundaries.md.",
        trigger: trigger,
        line_no: meta[:line],
        column: meta[:column]
      )

    %{ctx | issues: [issue | ctx.issues]}
  end
end
