defmodule MetricFlowSpex do
  @moduledoc """
  Boundary definition for BDD specifications.

  This boundary enforces surface-layer testing by only allowing dependencies
  on the Web layer and test support. Spex files cannot access context modules
  directly - all testing must go through the UI.
  """

  use Boundary, deps: [MetricFlowWeb, MetricFlowTest], exports: []
end
