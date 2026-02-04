defmodule MetricFlow.UserPreferences do
  @moduledoc """
  The UserPreferences context.
  """

  use Boundary, deps: [MetricFlow.Users, MetricFlow.Infrastructure], exports: [UserPreference]

  import Ecto.Query, warn: false
  alias MetricFlow.Infrastructure.Repo

  alias MetricFlow.UserPreferences.UserPreference
  alias MetricFlow.Users.Scope

  @doc """
  Subscribes to scoped notifications about user_preference changes.

  The broadcasted messages match the pattern:

    * {:created, %UserPreference{}}
    * {:updated, %UserPreference{}}
    * {:deleted, %UserPreference{}}

  """
  def subscribe_user_preferences(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(MetricFlow.PubSub, "user:#{key}:user_preferences")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{key}:user_preferences", message)
  end

  @doc """
  Loads user preferences into the scope.

  This should be called from the web layer when building a user's scope.
  Returns the scope with active_account and active_project populated.
  """
  def load_into_scope(%Scope{} = scope) do
    case get_user_preference(scope) do
      {:ok, preferences} -> Scope.with_preferences(scope, preferences)
      {:error, :not_found} -> scope
    end
  end

  @doc """
  Gets user preferences for the scoped user.

  Returns {:ok, %UserPreference{}} if preferences exist, or {:error, :not_found} if they don't.

  ## Examples

      iex> get_user_preference(scope)
      {:ok, %UserPreference{}}

      iex> get_user_preference(scope)
      {:error, :not_found}

  """
  def get_user_preference(%Scope{} = scope) do
    UserPreference
    |> preload([:active_account])
    |> Repo.get_by(user_id: scope.user.id)
    |> case do
      nil -> {:error, :not_found}
      user_preference -> {:ok, user_preference}
    end
  end

  @doc """
  Gets user preferences for the scoped user.

  Raises `Ecto.NoResultsError` if the User preference does not exist.

  ## Examples

      iex> get_user_preference!(scope)
      %UserPreference{}

      iex> get_user_preference!(scope)
      ** (Ecto.NoResultsError)

  """
  def get_user_preference!(%Scope{} = scope) do
    UserPreference
    |> preload([:active_account])
    |> Repo.get_by!(user_id: scope.user.id)
  end

  @doc """
  Creates user preferences for the scoped user.

  ## Examples

      iex> create_user_preferences(scope, %{field: value})
      {:ok, %UserPreference{}}

      iex> create_user_preferences(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_preferences(%Scope{} = scope, attrs) do
    %UserPreference{}
    |> UserPreference.changeset(attrs, scope)
    |> Repo.insert()
    |> case do
      {:ok, user_preference} ->
        user_preference = Repo.preload(user_preference, [:active_account])
        broadcast(scope, {:created, user_preference})
        {:ok, user_preference}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates user preferences for the scoped user.

  ## Examples

      iex> update_user_preferences(scope, %{field: new_value})
      {:ok, %UserPreference{}}

      iex> update_user_preferences(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_preferences(%Scope{} = scope, attrs) do
    user_preference = get_user_preference!(scope)

    user_preference
    |> UserPreference.changeset(attrs, scope)
    |> Repo.update()
    |> case do
      {:ok, user_preference} ->
        user_preference = Repo.preload(user_preference, [:active_account])
        broadcast(scope, {:updated, user_preference})
        {:ok, user_preference}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes user preferences for the scoped user.

  ## Examples

      iex> delete_user_preferences(scope)
      {:ok, %UserPreference{}}

      iex> delete_user_preferences(scope)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_preferences(%Scope{} = scope) do
    user_preference = get_user_preference!(scope)

    with {:ok, user_preference = %UserPreference{}} <-
           Repo.delete(user_preference) do
      broadcast(scope, {:deleted, user_preference})
      {:ok, user_preference}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_preference changes.

  ## Examples

      iex> change_user_preferences(scope)
      %Ecto.Changeset{data: %UserPreference{}}

  """
  def change_user_preferences(%Scope{} = scope, attrs \\ %{}) do
    case get_user_preference(scope) do
      {:ok, user_preference} ->
        UserPreference.changeset(user_preference, attrs, scope)

      {:error, :not_found} ->
        UserPreference.changeset(%UserPreference{}, attrs, scope)
    end
  end

  @doc """
  Selects an active account for the user.

  ## Examples

      iex> select_active_account(scope, 123)
      {:ok, %UserPreference{}}

      iex> select_active_account(scope, invalid_id)
      {:error, %Ecto.Changeset{}}

  """
  def select_active_account(%Scope{} = scope, account_id) do
    attrs = %{active_account_id: account_id}

    case get_user_preference(scope) do
      {:ok, _user_preference} ->
        update_user_preferences(scope, attrs)

      {:error, :not_found} ->
        create_user_preferences(scope, attrs)
    end
  end

  @doc """
  Generates a new token for the user.

  ## Examples

      iex> generate_token(scope)
      {:ok, %UserPreference{}}

  """
  def generate_token(%Scope{} = scope) do
    new_token = Phoenix.Token.sign(MetricFlowWeb.Endpoint, "user_api_token", scope.user.id)

    case get_user_preference(scope) do
      {:ok, _user_preference} ->
        update_user_preferences(scope, %{token: new_token})

      {:error, :not_found} ->
        create_user_preferences(scope, %{token: new_token})
    end
  end
end
