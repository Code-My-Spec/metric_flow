defmodule MetricFlow.Repo.Migrations.CreateMetricEntities do
  use Ecto.Migration

  def change do
    create table(:user_metric_entities) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_id, :string, null: false
      add :display_name, :string, null: false, default: ""
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_metric_entities, [:user_id, :provider, :entity_id],
             name: :user_metric_entities_identity_index
           )
  end
end
