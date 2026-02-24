defmodule MetricFlow.Repo.Migrations.CreateMetrics do
  use Ecto.Migration

  def change do
    create table(:metrics) do
      add :metric_type, :string, null: false
      add :metric_name, :string, null: false
      add :value, :float, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :provider, :string, null: false
      add :dimensions, :map, null: false, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:metrics, [:user_id, :provider])
    create index(:metrics, [:user_id, :metric_name, :recorded_at])
    create index(:metrics, [:user_id, :metric_type])
  end
end
