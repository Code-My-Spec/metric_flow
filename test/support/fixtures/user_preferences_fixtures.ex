defmodule MetricFlow.UserPreferencesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MetricFlow.UserPreferences` context.
  """

  import MetricFlow.AccountsFixtures

  @doc """
  Generate a user_preference.
  """
  def user_preference_fixture(scope, attrs \\ %{}) do
    # Create actual account and project if not provided
    account = account_fixture()

    attrs =
      Enum.into(attrs, %{
        active_account_id: account.id,
        token: "some token"
      })

    {:ok, user_preference} = MetricFlow.UserPreferences.create_user_preferences(scope, attrs)
    user_preference
  end
end
