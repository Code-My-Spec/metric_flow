defmodule MetricFlow.Metrics.EntityMetricRepository do
  @moduledoc "Account-authorized storage for channel entities and their observations."
  import Ecto.Query

  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Metrics.{MetricEntity, EntityMetricObservation, EntityMetricCursor}
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  def authorize(%Scope{user: %{id: user_id}, account_id: account_id}, access)
      when is_integer(account_id) and access in [:read, :write] do
    query =
      from(m in AccountMember,
        where: m.user_id == ^user_id and m.account_id == ^account_id
      )

    query =
      if access == :write do
        where(query, [m], m.role in [:owner, :admin, :account_manager])
      else
        query
      end

    if Repo.exists?(query), do: :ok, else: {:error, :unauthorized}
  end

  def authorize(%Scope{}, _access), do: {:error, :unauthorized}

  def upsert_channel(%Scope{} = scope, external_id, attrs)
      when is_binary(external_id) and byte_size(external_id) > 0 do
    with :ok <- authorize(scope, :write) do
      %MetricEntity{
        account_id: scope.account_id,
        provider: "youtube",
        entity_type: "channel",
        external_id: external_id
      }
      |> MetricEntity.changeset(attrs)
      |> Repo.insert(
        on_conflict: {:replace, [:display_name, :published_at, :metadata, :updated_at]},
        conflict_target: [:account_id, :provider, :entity_type, :external_id],
        returning: true
      )
    end
  end

  def upsert_channel(%Scope{}, _external_id, _attrs), do: {:error, :invalid_channel_id}

  def get_channel(%Scope{} = scope, entity_id) do
    with :ok <- authorize(scope, :read) do
      case Repo.one(channel_query(scope, entity_id)) do
        nil -> {:error, :not_found}
        entity -> {:ok, entity}
      end
    end
  end

  def list_channels(%Scope{} = scope) do
    with :ok <- authorize(scope, :read) do
      {:ok,
       Repo.all(
         from(e in MetricEntity,
           where:
             e.account_id == ^scope.account_id and e.provider == "youtube" and
               e.entity_type == "channel",
           order_by: e.id
         )
       )}
    end
  end

  def list_observations(%Scope{} = scope, entity_id) do
    with {:ok, _entity} <- get_channel(scope, entity_id) do
      {:ok,
       Repo.all(
         from(o in EntityMetricObservation,
           where:
             o.account_id == ^scope.account_id and o.entity_id == ^entity_id and
               o.breakdown_type == "total" and o.breakdown_key == "all",
           order_by: [asc: o.report_date, asc: o.metric_name]
         )
       )}
    end
  end

  def get_cursor(%Scope{} = scope, entity_id, family, timezone) do
    with {:ok, _entity} <- get_channel(scope, entity_id) do
      date =
        Repo.one(
          from(c in EntityMetricCursor,
            where:
              c.account_id == ^scope.account_id and c.entity_id == ^entity_id and
                c.source_report == ^family and c.report_timezone == ^timezone,
            select: c.through_date
          )
        )

      {:ok, date}
    end
  end

  def persist_report(%Scope{} = scope, entity_id, family, range, observations, fetched_at) do
    with :ok <- authorize(scope, :write),
         {:ok, rows} <-
           MetricFlow.Metrics.ChannelReportSlice.validate(
             scope.account_id,
             entity_id,
             family,
             range,
             observations,
             fetched_at
           ) do
      Repo.transaction(fn ->
        persist_validated_report(scope, entity_id, family, range, rows, fetched_at)
      end)
    end
  end

  defp persist_validated_report(scope, entity_id, family, range, rows, fetched_at) do
    lock_channel!(scope, entity_id)

    timezone = MetricFlow.Metrics.YouTubeMetricDefinitions.report_timezone()

    cursor_query = cursor_query(scope, entity_id, family, timezone)

    cursor = Repo.one(cursor_query)
    {first, last} = range
    validate_progress!(cursor, first, fetched_at)

    slice = report_slice_query(scope, entity_id, family, timezone, first, last)

    if Repo.exists?(where(slice, [o], o.fetched_at > ^fetched_at)),
      do: Repo.rollback(:stale_report)

    Repo.delete_all(slice)
    count = insert_observations(rows)

    through_date = latest_through_date(cursor, last)

    Repo.insert!(
      %EntityMetricCursor{
        account_id: scope.account_id,
        entity_id: entity_id,
        source_report: family,
        report_timezone: timezone,
        through_date: through_date
      },
      on_conflict: {:replace, [:through_date, :updated_at]},
      conflict_target: [:account_id, :entity_id, :source_report, :report_timezone]
    )

    %{observations_written: count, through_date: through_date}
  end

  defp lock_channel!(scope, entity_id) do
    entity = scope |> channel_query(entity_id) |> lock("FOR UPDATE") |> Repo.one()
    if is_nil(entity), do: Repo.rollback(:not_found)

    case authorize(scope, :write) do
      :ok -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp cursor_query(scope, entity_id, family, timezone) do
    from(c in EntityMetricCursor,
      where:
        c.account_id == ^scope.account_id and c.entity_id == ^entity_id and
          c.source_report == ^family and c.report_timezone == ^timezone
    )
  end

  defp report_slice_query(scope, entity_id, family, timezone, first, last) do
    from(o in EntityMetricObservation,
      where:
        o.account_id == ^scope.account_id and o.entity_id == ^entity_id and
          o.source_report == ^family and o.report_timezone == ^timezone and
          o.breakdown_type == "total" and o.breakdown_key == "all" and
          o.report_date >= ^first and o.report_date <= ^last
    )
  end

  defp insert_observations(rows) do
    now = DateTime.utc_now()
    fields = EntityMetricObservation.__schema__(:fields) -- [:id]

    entries =
      Enum.map(rows, fn row ->
        row
        |> Map.from_struct()
        |> Map.take(fields)
        |> Map.merge(%{inserted_at: now, updated_at: now})
      end)

    entries
    |> Enum.chunk_every(1000)
    |> Enum.reduce(0, fn batch, total ->
      {inserted, _} = Repo.insert_all(EntityMetricObservation, batch)
      total + inserted
    end)
  end

  defp latest_through_date(cursor, last) do
    if cursor && Date.compare(cursor.through_date, last) == :gt,
      do: cursor.through_date,
      else: last
  end

  defp validate_progress!(nil, _first, _fetched_at), do: :ok

  # Snapshots describe collection time; missed days cannot be backfilled.
  defp validate_progress!(%EntityMetricCursor{source_report: "snapshot"}, _first, _fetched_at),
    do: :ok

  defp validate_progress!(cursor, first, _fetched_at) do
    if Date.compare(first, Date.add(cursor.through_date, 1)) == :gt,
      do: Repo.rollback(:noncontiguous_report)
  end

  defp channel_query(scope, entity_id) do
    from(e in MetricEntity,
      where:
        e.id == ^entity_id and e.account_id == ^scope.account_id and
          e.provider == "youtube" and e.entity_type == "channel"
    )
  end
end
