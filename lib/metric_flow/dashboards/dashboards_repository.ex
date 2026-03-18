defmodule MetricFlow.Dashboards.DashboardsRepository do
  @moduledoc """
  Data access layer for Dashboard CRUD operations.

  All queries are filtered by user_id via the Scope struct for multi-tenant
  isolation. Provides list, get, create, update, and delete operations.
  Results are ordered by most recently created first.
  """

  import Ecto.Query

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # list_dashboards/1
  # ---------------------------------------------------------------------------

  @doc """
  Returns all user-owned (non-built-in) dashboards for the scoped user,
  ordered by most recently created.
  """
  @spec list_dashboards(Scope.t()) :: list(Dashboard.t())
  def list_dashboards(%Scope{user: user}) do
    from(d in Dashboard,
      where: d.user_id == ^user.id and d.built_in == false,
      order_by: [desc: d.inserted_at, desc: d.id]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # list_canned_dashboards/0
  # ---------------------------------------------------------------------------

  @doc """
  Returns all system-provided built-in dashboards, ordered by name.
  """
  @spec list_canned_dashboards() :: list(Dashboard.t())
  def list_canned_dashboards do
    from(d in Dashboard,
      where: d.built_in == true,
      order_by: [asc: d.name, asc: d.id]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # get_dashboard/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single dashboard for the scoped user by ID.

  Returns `{:ok, dashboard}` when found, or `{:error, :not_found}` when the
  dashboard does not exist or belongs to a different user.
  """
  @spec get_dashboard(Scope.t(), integer()) :: {:ok, Dashboard.t()} | {:error, :not_found}
  def get_dashboard(%Scope{user: user}, id) do
    result =
      from(d in Dashboard,
        where: d.user_id == ^user.id and d.id == ^id
      )
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      dashboard -> {:ok, dashboard}
    end
  end

  # ---------------------------------------------------------------------------
  # create_dashboard/2
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new dashboard for the scoped user.

  Merges user_id from the scope into attrs before inserting, ensuring the
  scope's user_id always takes precedence over any user_id in attrs.
  """
  @spec create_dashboard(Scope.t(), map()) :: {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  def create_dashboard(%Scope{user: user}, attrs) do
    attrs_with_user =
      attrs
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
      |> Map.put("user_id", user.id)

    %Dashboard{}
    |> Dashboard.changeset(attrs_with_user)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # update_dashboard/2
  # ---------------------------------------------------------------------------

  @doc """
  Updates an existing dashboard with the given attributes.
  """
  @spec update_dashboard(Dashboard.t(), map()) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  def update_dashboard(%Dashboard{} = dashboard, attrs) do
    dashboard
    |> Dashboard.changeset(attrs)
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # delete_dashboard/1
  # ---------------------------------------------------------------------------

  @doc """
  Deletes a dashboard.

  Returns `{:ok, dashboard}` with the deleted record, or
  `{:error, changeset}` if deletion fails.
  """
  @spec delete_dashboard(Dashboard.t()) :: {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  def delete_dashboard(%Dashboard{} = dashboard) do
    Repo.delete(dashboard)
  end
end
