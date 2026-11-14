defmodule MetricFlow.Repo.Migrations.CreateDashboardVersions do
  use Ecto.Migration

  def change do
    create table(:dashboard_versions) do
      add :visualizations, {:array, :map}, null: false
      add :dashboard_id, references(:dashboards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:dashboard_versions, [:dashboard_id])
  end
end
