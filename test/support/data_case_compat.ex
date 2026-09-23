defmodule MetricFlow.DataCase do
  @moduledoc """
  Compatibility shim: Phoenix generators emit `use MetricFlow.DataCase`.
  The real case module is `MetricFlowTest.DataCase` — forward to it.

  See `MetricFlowWeb.ConnCase` for the rationale.
  """
  defmacro __using__(opts) do
    quote do
      use MetricFlowTest.DataCase, unquote(opts)
    end
  end
end
