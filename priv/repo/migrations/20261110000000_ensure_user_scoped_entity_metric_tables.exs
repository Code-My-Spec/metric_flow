defmodule MetricFlow.Repo.Migrations.EnsureUserScopedEntityMetricTables do
  use Ecto.Migration

  def change do
    # Earlier migration versions may already be recorded against the legacy
    # account-scoped tables. Create the separate user-scoped tables in that case.
    create_if_not_exists table(:entity_metric_sync_cursors) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_id, :string, null: false
      add :metric_name, :string, null: false
      add :synced_through, :date, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(
                           :entity_metric_sync_cursors,
                           [:user_id, :provider, :entity_id, :metric_name],
                           name: :entity_metric_sync_cursors_identity_index
                         )

    create_if_not_exists table(:entity_metric_daily_observations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_id, :string, null: false
      add :metric_name, :string, null: false
      add :observed_on, :date, null: false
      add :value, :float, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(
                           :entity_metric_daily_observations,
                           [:user_id, :provider, :entity_id, :metric_name, :observed_on],
                           name: :entity_metric_daily_observations_identity_index
                         )

    create_if_not_exists table(:user_metric_entities) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_id, :string, null: false
      add :display_name, :string, null: false, default: ""
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(
                           :user_metric_entities,
                           [:user_id, :provider, :entity_id],
                           name: :user_metric_entities_identity_index
                         )
  end
end
