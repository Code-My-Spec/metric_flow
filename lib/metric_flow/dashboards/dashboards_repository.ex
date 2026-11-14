defmodule MetricFlow.Dashboards.DashboardsRepository do
  @moduledoc """
  Data access layer for Dashboard CRUD operations.

  All queries are filtered by user_id via the Scope struct for multi-tenant
  isolation. Provides list, get, create, update, and delete operations.
  Results are ordered by most recently created first.
  """

  import Ecto.Query

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Dashboards.DashboardVersion
  alias MetricFlow.Dashboards.DashboardVisualization
  alias MetricFlow.Dashboards.Visualization
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
      order_by: [desc: d.favorite, desc: d.updated_at, desc: d.id]
    )
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # list_canned_dashboards/0
  # ---------------------------------------------------------------------------

  # Story 75, criterion 1076: built-in dashboards are system-provided and
  # identical for every account, so they live in code rather than as
  # dashboards rows seeded by a migration -- there is nothing per-account
  # to persist, and no user can edit, rename or delete one. Negative ids
  # keep them permanently distinct from any real, DB-assigned (positive
  # serial) dashboard id.
  @canned_dashboards [
    %Dashboard{
      id: -1,
      name: "Marketing Overview",
      description: "Impressions, clicks, conversions and engagement across every connected platform.",
      built_in: true
    },
    %Dashboard{
      id: -2,
      name: "Revenue Analysis",
      description: "Revenue, expenses and return on ad spend.",
      built_in: true
    },
    %Dashboard{
      id: -3,
      name: "Platform Comparison",
      description: "Cost, conversions and click-through rate side by side across platforms.",
      built_in: true
    }
  ]

  @doc """
  Returns all system-provided built-in dashboards, ordered by name.
  """
  @spec list_canned_dashboards() :: list(Dashboard.t())
  def list_canned_dashboards, do: @canned_dashboards

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
  # get_dashboard_with_visualizations/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single dashboard for the scoped user by ID with its
  dashboard_visualizations and associated visualizations preloaded, ordered
  by position ascending.

  Returns `{:ok, dashboard}` when found, or `{:error, :not_found}` when the
  dashboard does not exist or belongs to a different user.
  """
  @spec get_dashboard_with_visualizations(Scope.t(), integer()) ::
          {:ok, Dashboard.t()} | {:error, :not_found}
  def get_dashboard_with_visualizations(%Scope{user: user}, id) do
    dvs_query =
      from(dv in DashboardVisualization,
        order_by: dv.position,
        preload: [:visualization]
      )

    result =
      from(d in Dashboard,
        where: d.user_id == ^user.id and d.id == ^id,
        preload: [dashboard_visualizations: ^dvs_query]
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
    |> paper_trail_save(&PaperTrail.insert/1)
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
    |> paper_trail_save(&PaperTrail.update/1)
  end

  # Story 74: versions the dashboard A2UI blob via paper_trail -- every
  # create/update of a Dashboard record gets a row in paper_trail's
  # `versions` table, including "restore creates a new version."
  # PaperTrail.insert/update return {:ok, %{model:, version:}} rather than
  # {:ok, struct} on success, so this adapts it to the plain Repo.insert/2
  # and Repo.update/2 shape this module's callers already expect.
  defp paper_trail_save(changeset, paper_trail_fun) do
    case paper_trail_fun.(changeset) do
      {:ok, %{model: dashboard}} -> {:ok, dashboard}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # replace_dashboard_visualizations/3
  # ---------------------------------------------------------------------------

  @doc """
  Replaces all visualizations for a dashboard in a single transaction.

  Deletes any existing DashboardVisualization records for the given dashboard,
  then creates a new Visualization record for each entry in `visualizations`
  and links it to the dashboard via a new DashboardVisualization record.

  Each visualization entry must be a map with `:metric_name`, `:chart_type`,
  and `:position` keys. The `metric_name` and `chart_type` are stored in the
  visualization's `vega_spec` so they can be recovered when loading the
  dashboard for editing.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec replace_dashboard_visualizations(Scope.t(), Dashboard.t(), list(map())) ::
          :ok | {:error, term()}
  def replace_dashboard_visualizations(
        %Scope{user: user},
        %Dashboard{id: dashboard_id},
        visualizations
      ) do
    Repo.transaction(fn ->
      from(dv in DashboardVisualization, where: dv.dashboard_id == ^dashboard_id)
      |> Repo.delete_all()

      Enum.each(visualizations, fn %{
                                     metric_name: metric_name,
                                     chart_type: chart_type,
                                     position: position
                                   } = viz ->
        vega_spec =
          Map.get(viz, :vega_spec) || %{"metric_name" => metric_name, "chart_type" => chart_type}

        {:ok, visualization} =
          %Visualization{}
          |> Visualization.changeset(%{
            name: metric_name,
            user_id: user.id,
            vega_spec: vega_spec
          })
          |> Repo.insert()

        %DashboardVisualization{}
        |> DashboardVisualization.changeset(%{
          dashboard_id: dashboard_id,
          visualization_id: visualization.id,
          position: position
        })
        |> Repo.insert!()
      end)
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
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

  # ---------------------------------------------------------------------------
  # delete_all_dashboards/1
  # ---------------------------------------------------------------------------

  @doc """
  Deletes every user-owned (non-built-in) dashboard for the scoped user.

  Used when the account through which these dashboards are managed is being
  deleted permanently. Cascades to dashboard_visualizations at the DB level.
  """
  @spec delete_all_dashboards(Scope.t()) :: :ok
  def delete_all_dashboards(%Scope{user: user}) do
    from(d in Dashboard, where: d.user_id == ^user.id and d.built_in == false)
    |> Repo.delete_all()

    :ok
  end

  # ---------------------------------------------------------------------------
  # create_dashboard_version/2
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # delete_paper_trail_versions/1
  # ---------------------------------------------------------------------------

  @doc """
  Deletes every paper_trail version row recorded for a dashboard.

  paper_trail's `versions` table is polymorphic (item_type/item_id, no
  foreign key), so these do not cascade when the dashboard row itself is
  deleted -- this must be called explicitly (Story 75, criterion 1069).
  """
  @spec delete_paper_trail_versions(integer()) :: :ok
  def delete_paper_trail_versions(dashboard_id) do
    from(v in PaperTrail.Version, where: v.item_type == "Dashboard" and v.item_id == ^dashboard_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Records a snapshot of a dashboard's visualizations as a new version.

  Returns `{:ok, version}` on success, `{:error, changeset}` on failure.
  """
  @spec create_dashboard_version(Dashboard.t(), [map()]) ::
          {:ok, DashboardVersion.t()} | {:error, Ecto.Changeset.t()}
  def create_dashboard_version(%Dashboard{id: dashboard_id}, visualizations) do
    %DashboardVersion{}
    |> DashboardVersion.changeset(%{dashboard_id: dashboard_id, visualizations: visualizations})
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # list_dashboard_versions/1
  # ---------------------------------------------------------------------------

  @doc """
  Returns all versions recorded for a dashboard, most recent first.
  """
  @spec list_dashboard_versions(Dashboard.t()) :: [DashboardVersion.t()]
  def list_dashboard_versions(%Dashboard{id: dashboard_id}) do
    from(v in DashboardVersion,
      where: v.dashboard_id == ^dashboard_id,
      order_by: [desc: v.inserted_at, desc: v.id]
    )
    |> Repo.all()
  end
end
