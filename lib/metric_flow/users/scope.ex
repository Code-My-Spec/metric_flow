defmodule MetricFlow.Users.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `MetricFlow.Users.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias MetricFlow.Users.User
  alias MetricFlow.UserPreferences

  defstruct user: nil,
            active_account: nil,
            active_account_id: nil,
            active_project: nil,
            active_project_id: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    scope = %__MODULE__{user: user}

    case UserPreferences.get_user_preference(scope) do
      {:ok, preferences} ->
        %__MODULE__{
          user: user,
          active_account: preferences.active_account,
          active_account_id: preferences.active_account_id,
          active_project: preferences.active_project,
          active_project_id: preferences.active_project_id
        }

      {:error, :not_found} ->
        scope
    end
  end

  def for_user(nil), do: nil
end
