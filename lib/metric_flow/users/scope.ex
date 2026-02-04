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

  defstruct user: nil,
            active_account: nil,
            active_account_id: nil,
            active_project: nil,
            active_project_id: nil

  @type t :: %__MODULE__{
          user: User.t() | nil,
          active_account: any(),
          active_account_id: String.t() | nil,
          active_project: any(),
          active_project_id: String.t() | nil
        }

  @doc """
  Creates a basic scope for the given user.

  To load user preferences (active account, project), use
  `MetricFlow.UserPreferences.load_into_scope/1` from the web layer.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Updates the scope with preference data.
  """
  def with_preferences(%__MODULE__{} = scope, nil), do: scope

  def with_preferences(%__MODULE__{} = scope, preferences) do
    %__MODULE__{
      scope
      | active_account: preferences.active_account,
        active_account_id: preferences.active_account_id,
        active_project: preferences.active_project,
        active_project_id: preferences.active_project_id
    }
  end
end
