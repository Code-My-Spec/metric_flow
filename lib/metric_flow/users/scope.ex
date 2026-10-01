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

  defstruct user: nil, account_id: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Returns a copy of `scope` with `account_id` set to the given value.

  For multi-account users, a scope on its own does not know which account
  the caller has switched to via the account switcher (`active_account_id`
  in socket assigns) -- without this, account-scoped queries fall back to
  resolving some arbitrary account for the user instead. LiveViews with an
  account switcher should call this once at mount and re-assign
  `:current_scope`, so every later read of `socket.assigns.current_scope`
  already carries the active account.
  """
  def put_account_id(%__MODULE__{} = scope, account_id) do
    %{scope | account_id: account_id}
  end
end
