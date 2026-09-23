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

  # Owns the sandbox directly rather than borrowing
  # `MetricFlowTest.DataCase.setup_sandbox/1`: spex are a separate boundary
  # from test support, and reaching into DataCase would force MetricFlowSpex to
  # depend on MetricFlowTest for one function.
  setup tags do
    pid = Sandbox.start_owner!(MetricFlow.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
