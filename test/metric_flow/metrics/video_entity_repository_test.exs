defmodule MetricFlow.Metrics.VideoEntityRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  alias MetricFlow.Accounts
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope

  @published ~U[2025-01-01 00:00:00.000000Z]

  defp account_scope(user) do
    scope = Scope.for_user(user)

    {:ok, account} =
      Accounts.create_team_account(scope, %{
        name: "Video storage",
        slug: "video-storage-#{System.unique_integer([:positive])}"
      })

    Scope.put_account_id(scope, account.id)
  end

  setup do
    scope = account_scope(user_fixture())
    {:ok, channel} = Metrics.upsert_channel(scope, "channel-one", %{display_name: "One"})
    %{scope: scope, channel: channel}
  end

  test "renames preserve identity and publication metadata", %{scope: scope, channel: channel} do
    attrs = %{display_name: "Original", published_at: @published}
    assert {:ok, video} = Metrics.upsert_video(scope, channel.id, "video-one", attrs)

    assert {:ok, renamed} =
             Metrics.upsert_video(scope, channel.id, "video-one", %{
               attrs
               | display_name: "Renamed"
             })

    assert renamed.id == video.id
    assert renamed.parent_entity_id == channel.id
    assert renamed.published_at == @published
    assert {:ok, [stored]} = Metrics.list_videos(scope, channel.id)
    assert stored.display_name == "Renamed"
  end

  test "video identities and reads are account scoped", %{scope: scope, channel: channel} do
    other = account_scope(scope.user)
    {:ok, other_channel} = Metrics.upsert_channel(other, "channel-one", %{display_name: "Other"})
    attrs = %{display_name: "Video", published_at: @published}
    assert {:ok, video} = Metrics.upsert_video(scope, channel.id, "shared-id", attrs)
    assert {:ok, other_video} = Metrics.upsert_video(other, other_channel.id, "shared-id", attrs)
    refute other_video.id == video.id
    assert {:error, :not_found} = Metrics.get_video(other, video.id)
    assert {:error, :not_found} = Metrics.upsert_video(other, channel.id, "new-id", attrs)
    stranger = Scope.for_user(user_fixture()) |> Scope.put_account_id(scope.account_id)
    assert {:error, :unauthorized} = Metrics.get_video(stranger, video.id)
    assert {:error, :unauthorized} = Metrics.upsert_video(stranger, channel.id, "new-id", attrs)
  end

  test "a conflicting channel cannot reparent or rename an existing video", %{
    scope: scope,
    channel: channel
  } do
    {:ok, other_channel} = Metrics.upsert_channel(scope, "channel-two", %{display_name: "Two"})
    attrs = %{display_name: "Original", published_at: @published}
    {:ok, video} = Metrics.upsert_video(scope, channel.id, "video-one", attrs)

    assert {:error, :channel_mismatch} =
             Metrics.upsert_video(scope, other_channel.id, "video-one", %{
               attrs
               | display_name: "Wrong"
             })

    assert {:ok, stored} = Metrics.get_video(scope, video.id)
    assert stored.parent_entity_id == channel.id
    assert stored.display_name == "Original"
    assert {:error, :not_found} = Metrics.upsert_video(scope, video.id, "nested-video", attrs)
  end

  test "read-only members cannot write videos", %{scope: scope, channel: channel} do
    reader = user_fixture()
    {:ok, _} = Accounts.add_user_to_account(scope, reader.id, scope.account_id, :read_only)
    reader_scope = Scope.for_user(reader) |> Scope.put_account_id(scope.account_id)
    attrs = %{display_name: "Video", published_at: @published}
    {:ok, video} = Metrics.upsert_video(scope, channel.id, "video-one", attrs)
    assert {:ok, _} = Metrics.get_video(reader_scope, video.id)

    assert {:error, :unauthorized} =
             Metrics.upsert_video(reader_scope, channel.id, "video-one", attrs)
  end
end
