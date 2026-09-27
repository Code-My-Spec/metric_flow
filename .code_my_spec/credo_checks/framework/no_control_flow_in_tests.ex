defmodule CodeMySpec.Check.Warning.NoControlFlowInTests do
  @moduledoc """
  Credo check that forbids imperative control flow (`case`, `if`, `unless`,
  `cond`, `try`) anywhere in a test file (`_test.exs`) or BDD spec file
  (`_spex.exs`) — including `defp` helpers, `setup` blocks and stub plugs, not
  only the test bodies. See the `:check` explanation for rationale.
  """

  use Credo.Check,
    id: "CMS0003",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Imperative control flow (`case`, `if`, `unless`, `cond`, `try/rescue`)
      is not allowed **anywhere** in a test file (`_test.exs`) or BDD spec
      file (`_spex.exs`). The whole file, not only the test body: `defp`
      helpers, `setup` blocks and stub plugs are all covered.

      That breadth is the rule, not an accident of implementation. A test
      file is read to find out what the system is claimed to do, and a branch
      anywhere in it means the answer depends on something the reader has to
      go and evaluate. Where the branch sits changes who has to trace it, not
      whether it has to be traced.

      ## Why a test body must not branch

      A test must be fully deterministic: you own the setup, so you know
      *exactly* what every value and shape will be, and you assert that exact
      thing. A branch is a contradiction — the test is reacting to state it
      claims to control. Either the setup isn't pinned down (fix the fixture
      so the outcome is known) or the branch guards a shape that cannot occur
      (delete it and assert directly).

      `if`/`case` to "handle either outcome" is the tell: if both outcomes are
      genuinely possible, the test is non-deterministic and can pass for the
      wrong reason. Decide which outcome you require, make the setup guarantee
      it, and assert it unconditionally — the test should *fail* when you
      don't get it, not quietly take the other branch.

      ## The three shapes that get flagged outside test bodies

      These are not test smells in themselves, and the fix is to move them
      rather than to argue with the finding.

      **Stub or fake-server routing** — `case conn.request_path do ... end`
      inside a `Req.Test.stub`. Dispatching on the request is the stub's job.
      Write it as multi-clause private functions, which is pattern matching in
      function heads rather than a branch:

          defp respond(%{request_path: "/v1/customers"} = conn), do: json(conn, ...)
          defp respond(%{request_path: "/v1/subscriptions"} = conn), do: json(conn, ...)

      A stub with more than a couple of routes belongs in `test/support`
      alongside the other fixtures, where this rule does not apply.

      **Extraction whose other branch raises** — `case Regex.run(...) do [_, id]
      -> id; _ -> raise "could not read the id from: \#{body}" end`. The intent is
      right; the branch is not the way to get it. Use multi-clause heads, which
      keep the message:

          defp story_id!(body), do: story_id_from(Regex.run(~r/\\(ID: (\\d+)\\)/, body), body)

          defp story_id_from([_, id], _body), do: id
          defp story_id_from(_none, body), do: raise "could not read story id from: \#{body}"

      A bare `[_, id] = Regex.run(...)` also removes the branch, but only reach
      for it when the matched value is self-describing. `Regex.run/2` returns
      `nil` on no match, so the MatchError reads `no match of right hand side
      value: nil` — it has thrown away the very haystack the raise was there to
      show you, and a spex that fails this way names nothing you can act on.

      **Teardown and environment helpers** — a `defp delete_ssh_key/1` that has
      to cope with present and absent. Resource management is not the test
      file's job; move it to `test/support` or express it with `on_exit`.

      ## What is always fine

      Pattern matching in function heads, `=` destructuring (`{:ok, value} =
      result`), `with` clauses, and `assert match?(pattern, value)`. Those are
      destructuring, not branching — they narrow to one path and fail loudly
      when reality disagrees, which is what a test is for.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    if test_or_spex?(filename) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    else
      []
    end
  end

  defp test_or_spex?(filename) do
    String.ends_with?(filename, "_test.exs") or String.ends_with?(filename, "_spex.exs")
  end

  defp walk({:case, meta, _} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "case"))}
  end

  defp walk({:if, meta, _} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "if"))}
  end

  defp walk({:unless, meta, _} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "unless"))}
  end

  defp walk({:cond, meta, _} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "cond"))}
  end

  defp walk({:try, meta, _} = ast, ctx) do
    {ast, put_issue(ctx, issue_for(ctx, meta, "try"))}
  end

  defp walk(ast, ctx) do
    {ast, ctx}
  end

  # The message says "anywhere in this file" rather than arguing about test
  # bodies. The previous wording — "a branch means the test is reacting to state
  # it should control" — justified a narrower rule than the one being enforced,
  # so the 104 findings it produced on this working copy read as false positives
  # rather than as a backlog. Most sit in `defp` helpers and stub plugs, where
  # that sentence is simply untrue, and a reader who checks it concludes the
  # check is broken (358799d7).
  defp issue_for(issue_meta, meta, construct) do
    format_issue(
      issue_meta,
      message:
        "Imperative `#{construct}` is not allowed anywhere in a _test.exs / _spex.exs " <>
          "file — helpers, setup blocks and stubs included, not just the test body. " <>
          "In a test body: pin the setup and assert the exact outcome. In a helper or " <>
          "stub: use multi-clause function heads, or move it to test/support.",
      trigger: construct,
      line_no: meta[:line],
      column: meta[:column]
    )
  end
end
