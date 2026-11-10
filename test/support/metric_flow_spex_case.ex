defmodule MetricFlowSpex.Case do
  @moduledoc """
  Base case for spex (BDD spec) tests.

  Wires up Phoenix.ConnTest for HTTP assertions, Phoenix.LiveViewTest for
  driving LiveViews, the SexySpex DSL (spex/scenario/given_/when_/then_), and
  the DB sandbox — so a spex file says `use MetricFlowSpex.Case` and nothing
  else.

  The 374 spex already here predate this and open with `use SexySpex` plus
  `use MetricFlowTest.ConnCase`. Both keep working; this is what new spex
  should use, and what the convention in `cms_new` generates for a fresh
  project.

  Specs compose givens and interact through the Web layer. Reaching into the
  application is `MetricFlowSpex.Fixtures`' job — the approved bridge, kept
  deliberately narrow.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      @endpoint MetricFlowWeb.Endpoint

      use MetricFlowWeb, :verified_routes
      use SexySpex

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import MetricFlowSpex.Case
    end
  end

  @doc "Waits for an asynchronously generated chart to appear in the LiveView."
  def await_chart(view, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    await_chart_until(view, deadline)
  end

  defp await_chart_until(view, deadline) do
    cond do
      Phoenix.LiveViewTest.has_element?(view, "#visualization-preview-chart") ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        ExUnit.Assertions.flunk("visualization chart did not appear within the deadline")

      true ->
        Process.sleep(20)
        await_chart_until(view, deadline)
    end
  end

  @doc "Waits for an asynchronous chat reply to finish, including error replies."
  def await_chat_completion(view, timeout_ms \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    await_chat_completion_until(view, deadline)
  end

  defp await_chat_completion_until(view, deadline) do
    cond do
      Phoenix.LiveViewTest.has_element?(view, "[data-role='chat-send-btn']:not([disabled])") ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        ExUnit.Assertions.flunk("visualization chat did not finish within the deadline")

      true ->
        Process.sleep(20)
        await_chat_completion_until(view, deadline)
    end
  end

  # Owns the sandbox directly rather than borrowing
  # `MetricFlowTest.DataCase.setup_sandbox/1`: spex are a separate boundary
  # from test support, and reaching into DataCase would force MetricFlowSpex to
  # depend on MetricFlowTest for one function.
  setup tags do
    # `mix spex` does not load test_helper.exs.
    MetricFlowTest.HermeticHttp.install()
    pid = Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
