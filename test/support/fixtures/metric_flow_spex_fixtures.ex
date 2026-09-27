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

  The 374 spex here drove everything through the Web layer with no bridge
  until now. Story 1099's webhook-correlation specs need to know which
  account a given user's webhook events belong to before firing the
  webhook — no UI surfaces an account id, so that lookup is the first
  function here.
  """
  use Boundary, top_level?: true, deps: [MetricFlow, MetricFlowTest]

  alias MetricFlow.Accounts
  alias MetricFlow.Users.Scope

  @doc """
  The personal account id for the user registered with `email`.

  For specs that need an account id to correlate a webhook or API payload
  with the account it should affect, without reading the DB directly.
  """
  @spec personal_account_id(String.t()) :: integer()
  def personal_account_id(email) do
    user = MetricFlowTest.UsersFixtures.get_user_by_email(email)
    scope = Scope.for_user(user)
    Accounts.get_personal_account_id(scope)
  end
end
