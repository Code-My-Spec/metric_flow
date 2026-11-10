defmodule MetricFlow.Repo.Migrations.CreateEntityMetricObservations do
  use Ecto.Migration

  def change do
    create table(:entity_metric_daily_observations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_id, :string, null: false
      add :metric_name, :string, null: false
      add :observed_on, :date, null: false
      add :value, :float, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :entity_metric_daily_observations,
             [:user_id, :provider, :entity_id, :metric_name, :observed_on],
             name: :entity_metric_daily_observations_identity_index
           )
  end
end
