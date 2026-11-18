defmodule MetricFlow.Dashboards.VisualizationsRepository do
  @moduledoc """
  Data access layer for Visualization CRUD operations.

  All queries filter by user_id via Scope for multi-tenant isolation.
  Provides list, get, create, update, and delete operations for visualization
  specs, ordering results by most recently created first.
  """

  import Ecto.Query

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Dashboards.VisualizationMetric
  alias MetricFlow.Repo
  alias MetricFlow.AccountAccess
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # list_visualizations/1
  # ---------------------------------------------------------------------------

  @doc """
  Returns all visualizations for the scoped user, ordered by most recently
  modified first.
  """
  @spec list_visualizations(Scope.t()) :: list(Visualization.t())
  def list_visualizations(%Scope{} = scope) do
    from(v in scoped(scope), order_by: [desc: v.updated_at, desc: v.id])
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # get_visualization/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single visualization for the scoped user by ID.

  Returns {:ok, visualization} if found, {:error, :not_found} if the record
  does not exist or belongs to a different user.
  """
  @spec get_visualization(Scope.t(), integer()) ::
          {:ok, Visualization.t()} | {:error, :not_found}
  def get_visualization(%Scope{} = scope, id) do
    result =
      from(v in scoped(scope), where: v.id == ^id)
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      visualization -> {:ok, visualization}
    end
  end

  # ---------------------------------------------------------------------------
  # create_visualization/2
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new visualization for the scoped user.

  Merges user_id from the scope into attrs before inserting, ensuring the
  scope's user_id always takes precedence over any user_id in the attrs map.
  """
  @spec create_visualization(Scope.t(), map()) ::
          {:ok, Visualization.t()} | {:error, Ecto.Changeset.t()}
  def create_visualization(%Scope{} = scope, attrs) do
    %Visualization{
      user_id: AccountAccess.user_id(scope),
      account_id: AccountAccess.account_id(scope)
    }
    |> Visualization.changeset(drop_owner(attrs))
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # update_visualization/2
  # ---------------------------------------------------------------------------

  @doc """
  Updates an existing visualization with the given attributes.
  """
  @spec update_visualization(Visualization.t(), map()) ::
          {:ok, Visualization.t()} | {:error, Ecto.Changeset.t()}
  def update_visualization(%Visualization{} = visualization, attrs) do
    visualization
    |> Visualization.changeset(drop_owner(attrs))
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # delete_visualization/1
  # ---------------------------------------------------------------------------

  @doc """
  Deletes a visualization.

  Returns {:ok, deleted_visualization} on success or
  {:error, changeset} if deletion fails.
  """
  @spec delete_visualization(Visualization.t()) ::
          {:ok, Visualization.t()} | {:error, Ecto.Changeset.t()}
  def delete_visualization(%Visualization{} = visualization) do
    Repo.delete(visualization)
  end

  # ---------------------------------------------------------------------------
  # duplicate_visualization/1
  # ---------------------------------------------------------------------------

  @doc """
  Creates an independent copy of a visualization, including its bound
  metrics, owned by the same user.
  """
  @spec duplicate_visualization(Visualization.t()) ::
          {:ok, Visualization.t()} | {:error, Ecto.Changeset.t()}
  def duplicate_visualization(%Visualization{} = original) do
    attrs = %{
      name: original.name <> " (Copy)",
      vega_spec: original.vega_spec,
      shareable: false
    }

    copy = %Visualization{user_id: original.user_id, account_id: original.account_id}

    with {:ok, copy} <- copy |> Visualization.changeset(attrs) |> Repo.insert() do
      metric_names = get_visualization_metric_names(original)
      set_visualization_metrics(copy, metric_names)
      {:ok, copy}
    end
  end

  # ---------------------------------------------------------------------------
  # Visualization metrics
  # ---------------------------------------------------------------------------

  @doc """
  Replaces the bound metrics for a visualization.

  Deletes existing bindings and inserts new ones. The first metric is
  assigned role "primary", the rest "overlay".
  """
  @spec set_visualization_metrics(Visualization.t(), [String.t()]) :: :ok
  def set_visualization_metrics(%Visualization{id: viz_id}, metric_names) do
    Repo.delete_all(from(vm in VisualizationMetric, where: vm.visualization_id == ^viz_id))

    now = DateTime.utc_now()

    entries =
      metric_names
      |> Enum.with_index()
      |> Enum.map(fn {name, idx} ->
        %{
          visualization_id: viz_id,
          metric_name: name,
          role: if(idx == 0, do: "primary", else: "overlay"),
          inserted_at: now,
          updated_at: now
        }
      end)

    if entries != [], do: Repo.insert_all(VisualizationMetric, entries)
    :ok
  end

  @doc """
  Returns the list of metric names bound to a visualization.
  """
  @spec get_visualization_metric_names(Visualization.t()) :: [String.t()]
  def get_visualization_metric_names(%Visualization{id: viz_id}) do
    from(vm in VisualizationMetric,
      where: vm.visualization_id == ^viz_id,
      order_by: [asc: vm.id],
      select: vm.metric_name
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # delete_all_visualizations/1
  # ---------------------------------------------------------------------------

  @doc """
  Deletes every visualization for the scoped user.

  Used when the account through which these visualizations are managed is
  being deleted permanently. Cascades to visualization_metrics and
  dashboard_visualizations at the DB level.
  """
  @spec delete_all_visualizations(Scope.t()) :: :ok
  def delete_all_visualizations(%Scope{} = scope) do
    scope |> scoped() |> Repo.delete_all()
    :ok
  end

  defp scoped(%Scope{} = scope), do: AccountAccess.scope_query(Visualization, scope)

  # Ownership comes from the scope (or the original record), never from params.
  defp drop_owner(attrs), do: Map.drop(attrs, [:user_id, :account_id, "user_id", "account_id"])
end
