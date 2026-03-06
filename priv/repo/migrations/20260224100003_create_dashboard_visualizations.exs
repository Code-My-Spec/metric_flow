defmodule MetricFlow.Repo.Migrations.CreateDashboardVisualizations do
  use Ecto.Migration

  def change do
    create table(:dashboard_visualizations) do
      add :position, :integer, null: false
      add :size, :string, null: false, default: "medium"
      add :dashboard_id, references(:dashboards, on_delete: :delete_all), null: false
      add :visualization_id, references(:visualizations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:dashboard_visualizations, [:dashboard_id])
    create index(:dashboard_visualizations, [:visualization_id])
    create unique_index(:dashboard_visualizations, [:dashboard_id, :visualization_id])
  end
end
