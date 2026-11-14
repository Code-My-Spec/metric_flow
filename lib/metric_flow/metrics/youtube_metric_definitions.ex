defmodule MetricFlow.Metrics.YouTubeMetricDefinitions do
  @moduledoc "Units and aggregation semantics for YouTube channel-total observations."

  @counts ~w(views engagedViews subscribersGained subscribersLost likes dislikes comments shares videosAddedToPlaylists videosRemovedFromPlaylists)
  @snapshots ~w(subscriberCount viewCount videoCount)
  @definitions Map.merge(
                 Map.new(
                   @counts,
                   &{&1, %{family: "analytics", kind: "daily", unit: "count", aggregation: :sum}}
                 ),
                 Map.new(
                   @snapshots,
                   &{&1,
                    %{family: "snapshot", kind: "snapshot", unit: "count", aggregation: :latest}}
                 )
               )
               |> Map.merge(%{
                 "estimatedMinutesWatched" => %{
                   family: "analytics",
                   kind: "daily",
                   unit: "minutes",
                   aggregation: :sum
                 },
                 "averageViewDuration" => %{
                   family: "analytics",
                   kind: "daily",
                   unit: "seconds",
                   aggregation: {:weighted, "views"}
                 },
                 "averageViewPercentage" => %{
                   family: "analytics",
                   kind: "daily",
                   unit: "percent",
                   aggregation: :per_entity
                 },
                 "estimatedRevenue" => %{
                   family: "revenue",
                   kind: "daily",
                   unit: "USD",
                   aggregation: :sum
                 },
                 "adImpressions" => %{
                   family: "revenue",
                   kind: "daily",
                   unit: "count",
                   aggregation: :sum
                 },
                 "cpm" => %{
                   family: "revenue",
                   kind: "daily",
                   unit: "USD_per_1000_impressions",
                   aggregation: {:weighted, "adImpressions"}
                 }
               })

  def fetch(name), do: Map.fetch(@definitions, name)

  def names(family) do
    @definitions
    |> Enum.filter(fn {_name, definition} -> definition.family == family end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  def families, do: ["analytics", "snapshot", "revenue"]
  def report_timezone, do: "America/Los_Angeles"

  def normalized_name(name), do: String.downcase(name)

  def original_name(normalized) do
    Enum.find_value(@definitions, fn {name, _definition} ->
      if normalized_name(name) == normalized, do: name
    end)
  end
end
