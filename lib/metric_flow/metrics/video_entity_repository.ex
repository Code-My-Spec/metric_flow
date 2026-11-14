defmodule MetricFlow.Metrics.VideoEntityRepository do
  @moduledoc "Account-authorized YouTube videos with immutable channel ownership."
  import Ecto.Query

  alias MetricFlow.Metrics.{EntityMetricRepository, MetricEntity}
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  def upsert_video(%Scope{} = scope, channel_id, external_id, attrs)
      when is_binary(external_id) and byte_size(external_id) > 0 do
    with :ok <- EntityMetricRepository.authorize(scope, :write) do
      Repo.transaction(fn ->
        lock_channel!(scope, channel_id)
        persist_video!(scope, channel_id, external_id, attrs)
      end)
    end
  end

  def upsert_video(%Scope{}, _channel_id, _external_id, _attrs),
    do: {:error, :invalid_video_id}

  def get_video(%Scope{} = scope, entity_id) do
    with :ok <- EntityMetricRepository.authorize(scope, :read) do
      case Repo.one(where(video_query(scope), [v], v.id == ^entity_id)) do
        nil -> {:error, :not_found}
        video -> {:ok, video}
      end
    end
  end

  def list_videos(%Scope{} = scope, channel_id) do
    with {:ok, _channel} <- EntityMetricRepository.get_channel(scope, channel_id) do
      videos =
        video_query(scope)
        |> where([v], v.parent_entity_id == ^channel_id)
        |> order_by([v], v.id)
        |> Repo.all()

      {:ok, videos}
    end
  end

  defp lock_channel!(scope, channel_id) do
    channel =
      Repo.one(
        from(e in MetricEntity,
          where:
            e.id == ^channel_id and e.account_id == ^scope.account_id and
              e.provider == "youtube" and e.entity_type == "channel",
          lock: "FOR UPDATE"
        )
      )

    if is_nil(channel), do: Repo.rollback(:not_found)

    case EntityMetricRepository.authorize(scope, :write) do
      :ok -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp persist_video!(scope, channel_id, external_id, attrs) do
    changeset =
      %MetricEntity{
        account_id: scope.account_id,
        provider: "youtube",
        entity_type: "video",
        external_id: external_id,
        parent_entity_id: channel_id
      }
      |> MetricEntity.changeset(attrs)
      |> Ecto.Changeset.validate_required([:published_at])

    result =
      Repo.insert(changeset,
        on_conflict: {:replace, [:display_name, :published_at, :metadata, :updated_at]},
        conflict_target: [:account_id, :provider, :entity_type, :external_id],
        returning: true
      )

    case result do
      {:ok, %{parent_entity_id: ^channel_id} = video} -> video
      {:ok, _video} -> Repo.rollback(:channel_mismatch)
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp video_query(scope) do
    from(v in MetricEntity,
      join: c in MetricEntity,
      on:
        c.id == v.parent_entity_id and
          c.account_id == v.account_id and c.provider == v.provider,
      where:
        v.account_id == ^scope.account_id and v.provider == "youtube" and
          v.entity_type == "video" and c.entity_type == "channel"
    )
  end
end
