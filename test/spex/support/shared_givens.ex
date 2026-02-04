defmodule MetricFlowSpex.SharedGivens do
  @moduledoc """
  Shared given steps for BDD specifications.

  Import these givens in your spec files:

      defmodule MyApp.FeatureSpex do
        use SexySpex
        import_givens MetricFlow.SharedGivens
        # ...
      end

  Add new shared givens here when you find yourself duplicating setup code
  across multiple specs.
  """

  use SexySpex.Givens

  # Example shared given:
  #
  # given_ :user_exists do
  #   user = MyApp.Fixtures.user_fixture()
  #   {:ok, %{user: user}}
  # end
end
