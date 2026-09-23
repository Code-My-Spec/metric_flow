defmodule MetricFlowWeb.ConnCase do
  @moduledoc """
  Compatibility shim: Phoenix generators emit `use MetricFlowWeb.ConnCase`.
  The real case module is `MetricFlowTest.ConnCase` — forward to it.

  `mix phx.gen.auth` / `phx.gen.live` / `phx.gen.html` hardcode the default
  case-module names in every test they emit; without this shim their output
  does not compile. Newly generated tests compile as-emitted — normalize them
  to the `MetricFlowTest.*` names whenever you next touch them.
  """
  defmacro __using__(opts) do
    quote do
      use MetricFlowTest.ConnCase, unquote(opts)
    end
  end
end
