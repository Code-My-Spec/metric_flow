defmodule MetricFlow.Repo.Migrations.AddNormalizedMetricNameToMetrics do
  use Ecto.Migration

  def change do
    alter table(:metrics) do
      add :normalized_metric_name, :string
    end

    create index(:metrics, [:user_id, :normalized_metric_name])
  end
end
