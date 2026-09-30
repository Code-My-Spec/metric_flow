defmodule MetricFlowTest.SyncStub do
  @moduledoc """
  Registers canned HTTP responses for a data-sync provider, for spex driving
  a real sync through the "trigger daily sync" button rather than calling a
  provider's `fetch_metrics/2` directly.

  A LiveView click can't pass a function through `render_click/1`, so the
  plug is registered by provider beforehand (see `MetricFlowTest.PlugStore`)
  and `DataSync.sync_integration/2` picks it up when it builds the sync job.
  """

  alias MetricFlowTest.PlugStore

  @doc """
  Registers a plug that always answers `body` with HTTP 200 for `provider`.
  """
  @spec stub_success(atom(), String.t()) :: :ok
  def stub_success(provider, body) do
    plug = fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end

    PlugStore.put_provider_plug(provider, plug)
  end

  @doc """
  Registers a plug for `provider` that answers 429 on its first call and 200
  with `body` on every call after, for specs exercising Oban's own retry —
  not a backoff loop in the provider itself.
  """
  @spec stub_quota_then_success(atom(), String.t()) :: :ok
  def stub_quota_then_success(provider, body) do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    plug = fn conn ->
      attempt = Agent.get_and_update(counter, &{&1, &1 + 1})
      conn = Plug.Conn.put_resp_content_type(conn, "application/json")
      send_quota_response(conn, attempt, body)
    end

    PlugStore.put_provider_plug(provider, plug)
  end

  defp send_quota_response(conn, 0, _body) do
    Plug.Conn.send_resp(conn, 429, Jason.encode!(%{"error" => "RESOURCE_EXHAUSTED"}))
  end

  defp send_quota_response(conn, _attempt, body) do
    Plug.Conn.send_resp(conn, 200, body)
  end

  @doc """
  A minimal valid GA4 `runReport` response body: one day, all core metrics.
  """
  @spec google_analytics_success_body() :: String.t()
  def google_analytics_success_body do
    Jason.encode!(%{
      "rows" => [
        %{
          "dimensionValues" => [%{"value" => Date.to_iso8601(Date.utc_today(), :basic)}],
          "metricValues" => [
            %{"value" => "600"},
            %{"value" => "1400"},
            %{"value" => "500"},
            %{"value" => "0.38"},
            %{"value" => "92.0"},
            %{"value" => "220"}
          ]
        }
      ]
    })
  end
end
