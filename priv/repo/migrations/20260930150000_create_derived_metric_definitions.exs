defmodule MetricFlow.Repo.Migrations.CreateDerivedMetricDefinitions do
  use Ecto.Migration

  def change do
    create table(:derived_metric_definitions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :numerator, :string, null: false
      add :denominator, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:derived_metric_definitions, [:user_id, :name])
  end
end
