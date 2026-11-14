defmodule MetricFlow.Metrics.UserEntityMetricRepository do
  @moduledoc """
  Scoped persistence for daily metrics belonging to external entities.

  An observation is identified by user, provider, entity, metric, and day.
  Repeated syncs replace its value, while different locations keep separate
  observations. Cursors track the last fully synced day for each series.
  """

  import Ecto.Query

  alias MetricFlow.Metrics.UserEntityMetricCursor
  alias MetricFlow.Metrics.UserEntityMetricObservation
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User

  @type observation_attrs :: map()
  @type cursor_attrs :: map()

  @doc "Inserts a daily observation or replaces the value for its identity."
  @spec upsert_observation(Scope.t(), observation_attrs()) ::
          {:ok, UserEntityMetricObservation.t()} | {:error, Ecto.Changeset.t()}
  def upsert_observation(%Scope{user: %User{id: user_id}}, attrs) when is_map(attrs) do
    %UserEntityMetricObservation{user_id: user_id}
    |> UserEntityMetricObservation.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:user_id, :provider, :entity_id, :metric_name, :observed_on],
      returning: true
    )
  end

  @doc "Atomically upserts a batch of daily observations in input order."
  @spec upsert_observations(Scope.t(), [observation_attrs()]) ::
          {:ok, [UserEntityMetricObservation.t()]} | {:error, Ecto.Changeset.t()}
  def upsert_observations(%Scope{} = scope, attrs_list) when is_list(attrs_list) do
    Repo.transaction(fn ->
      Enum.map(attrs_list, fn attrs ->
        case upsert_observation(scope, attrs) do
          {:ok, observation} -> observation
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  @doc "Lists the current user's observations with optional series and inclusive date filters."
  @spec list_observations(Scope.t(), keyword()) :: [UserEntityMetricObservation.t()]
  def list_observations(scope), do: list_observations(scope, [])

  def list_observations(%Scope{user: %User{id: user_id}}, opts) when is_list(opts) do
    from(observation in UserEntityMetricObservation, where: observation.user_id == ^user_id)
    |> filter_provider(Keyword.get(opts, :provider))
    |> filter_entity(Keyword.get(opts, :entity_id))
    |> filter_metric(Keyword.get(opts, :metric_name))
    |> filter_dates(Keyword.get(opts, :date_range))
    |> order_by([observation],
      asc: observation.observed_on,
      asc: observation.entity_id,
      asc: observation.metric_name
    )
    |> Repo.all()
  end

  @doc "Returns a cursor for one current-user series, or nil when none exists."
  @spec get_cursor(Scope.t(), atom(), String.t(), String.t()) :: UserEntityMetricCursor.t() | nil
  def get_cursor(%Scope{user: %User{id: user_id}}, provider, entity_id, metric_name)
      when is_atom(provider) and is_binary(entity_id) and is_binary(metric_name) do
    Repo.get_by(UserEntityMetricCursor,
      user_id: user_id,
      provider: provider,
      entity_id: entity_id,
      metric_name: metric_name
    )
  end

  @doc "Inserts or replaces the checkpoint for one current-user series."
  @spec upsert_cursor(Scope.t(), cursor_attrs()) ::
          {:ok, UserEntityMetricCursor.t()} | {:error, Ecto.Changeset.t()}
  def upsert_cursor(%Scope{user: %User{id: user_id}}, attrs) when is_map(attrs) do
    %UserEntityMetricCursor{user_id: user_id}
    |> UserEntityMetricCursor.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:synced_through, :updated_at]},
      conflict_target: [:user_id, :provider, :entity_id, :metric_name],
      returning: true
    )
  end

  defp filter_provider(query, nil), do: query
  defp filter_provider(query, provider), do: where(query, [row], row.provider == ^provider)

  defp filter_entity(query, nil), do: query
  defp filter_entity(query, entity_id), do: where(query, [row], row.entity_id == ^entity_id)

  defp filter_metric(query, nil), do: query
  defp filter_metric(query, metric_name), do: where(query, [row], row.metric_name == ^metric_name)

  defp filter_dates(query, nil), do: query

  defp filter_dates(query, {%Date{} = first, %Date{} = last}) do
    where(query, [row], row.observed_on >= ^first and row.observed_on <= ^last)
  end
end
