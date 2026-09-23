defmodule MetricFlowSpex.Fixtures do
  @moduledoc """
  The one seam through which a spex may reach application state.

  Its own top-level boundary rather than a member of `MetricFlowSpex`, and that
  is the whole point: the bridge needs wide deps to re-export anything useful,
  and if it sat inside the spex boundary those deps would be in scope for every
  `_spex.exs` file too, which defeats the seal. Wide deps here, narrow public
  surface out.

  **Keep it narrow.** Every function added is a permanent surface that spex
  depend on, and the equivalent bridge on CodeMySpec grew into something slated
  for trimming. Before adding one, check whether the spex can assert off the
  *surface* instead — a `then_` that reads the database is asserting against
  the writer rather than against what the user sees. Using an existing function
  is fine; adding one needs a real reason, said out loud.

  Empty on purpose. The 374 spex here drive everything through the Web layer
  and have never needed a bridge; this exists so the first one that genuinely
  does has somewhere to go that is not `MetricFlowTest`.
  """
  use Boundary, top_level?: true, deps: [MetricFlow, MetricFlowTest]
end
