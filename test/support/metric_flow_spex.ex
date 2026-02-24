defmodule MetricFlowSpex do
  @moduledoc "Top-level boundary for BDD spex modules."
  use Boundary, top_level?: true, deps: [MetricFlowWeb, MetricFlowTest]
end
