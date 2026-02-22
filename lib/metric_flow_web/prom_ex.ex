defmodule MetricFlowWeb.PromEx do
  @moduledoc """
  PromEx configuration for Prometheus metrics export to Fly.io managed Grafana.
  """
  use PromEx, otp_app: :metric_flow

  @impl true
  def plugins do
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix, router: MetricFlowWeb.Router, endpoint: MetricFlowWeb.Endpoint},
      PromEx.Plugins.Ecto,
      {PromEx.Plugins.PhoenixLiveView, duration_unit: :millisecond},
      {PromEx.Plugins.Oban, poll_rate: 5_000}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "fly-prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "phoenix_live_view.json"},
      {:prom_ex, "oban.json"}
    ]
  end
end
