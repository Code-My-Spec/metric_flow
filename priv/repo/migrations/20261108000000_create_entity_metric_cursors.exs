defmodule MetricFlow.Repo.Migrations.CreateEntityMetricCursors do
  use Ecto.Migration

  def change do
    create table(:entity_metric_sync_cursors) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_id, :string, null: false
      add :metric_name, :string, null: false
      add :synced_through, :date, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :entity_metric_sync_cursors,
             [:user_id, :provider, :entity_id, :metric_name],
             name: :entity_metric_sync_cursors_identity_index
           )
  end
end
