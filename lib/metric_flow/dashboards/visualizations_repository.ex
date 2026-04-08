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
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # list_visualizations/1
  # ---------------------------------------------------------------------------

  @doc """
  Returns all visualizations for the scoped user, ordered by most recently
  created first.
  """
  @spec list_visualizations(Scope.t()) :: list(Visualization.t())
  def list_visualizations(%Scope{user: user}) do
    from(v in Visualization,
      where: v.user_id == ^user.id,
      order_by: [desc: v.inserted_at, desc: v.id]
    )
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
  def get_visualization(%Scope{user: user}, id) do
    result =
      from(v in Visualization,
        where: v.user_id == ^user.id and v.id == ^id
      )
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
  def create_visualization(%Scope{user: user}, attrs) do
    attrs_with_user = Map.put(attrs, :user_id, user.id)

    %Visualization{}
    |> Visualization.changeset(attrs_with_user)
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
    |> Visualization.changeset(attrs)
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
end
