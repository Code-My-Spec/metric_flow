defmodule MetricFlow.Repo do
  use Ecto.Repo,
    otp_app: :metric_flow,
    adapter: Ecto.Adapters.Postgres
end
