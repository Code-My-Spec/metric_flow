defmodule MetricFlowTest do
  @moduledoc "Top-level boundary for test support modules."
  use Boundary, top_level?: true, deps: [MetricFlow]
end
