defmodule MetricFlow.Repo.Migrations.AddVisualizationMetrics do
  use Ecto.Migration

  def change do
    create table(:visualization_metrics) do
      add :visualization_id, references(:visualizations, on_delete: :delete_all), null: false
      add :metric_name, :string, null: false
      add :role, :string, default: "primary"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:visualization_metrics, [:visualization_id])
    create unique_index(:visualization_metrics, [:visualization_id, :metric_name])
  end
end
