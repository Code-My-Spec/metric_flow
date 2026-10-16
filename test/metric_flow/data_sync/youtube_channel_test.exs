defmodule MetricFlow.DataSync.YouTubeChannelTest do
  use ExUnit.Case, async: true
  alias MetricFlow.DataSync.YouTubeChannel

  @date ~D[2026-10-15]

  defp response(statistics) do
    %{
      "items" => [
        %{
          "id" => "selected-channel",
          "snippet" => %{"title" => "Channel", "publishedAt" => "2020-01-01T00:00:00Z"},
          "statistics" => statistics
        }
      ]
    }
  end

  test "preserves zero and assigns the collection date" do
    body = response(%{"subscriberCount" => "0", "viewCount" => "210000", "videoCount" => "80"})
    assert {:ok, channel} = YouTubeChannel.parse(body, "selected-channel", @date)
    assert channel.created_on == ~D[2020-01-01]
    assert Enum.all?(channel.snapshots, &(&1.report_date == @date))
    assert Enum.find(channel.snapshots, &(&1.metric_name == "subscriberCount")).value == 0
  end

  test "hidden subscriber totals remain unavailable" do
    body =
      response(%{"hiddenSubscriberCount" => true, "viewCount" => "210000", "videoCount" => "80"})

    assert {:ok, channel} = YouTubeChannel.parse(body, "selected-channel", @date)
    assert length(channel.snapshots) == 2
    refute Enum.any?(channel.snapshots, &(&1.metric_name == "subscriberCount"))
  end

  test "rejects a different channel and malformed counts" do
    body =
      response(%{"subscriberCount" => "4500", "viewCount" => "invalid", "videoCount" => "80"})

    assert {:error, :channel_not_found} = YouTubeChannel.parse(body, "other-channel", @date)
    assert {:error, :malformed_channel} = YouTubeChannel.parse(body, "selected-channel", @date)
  end
end
