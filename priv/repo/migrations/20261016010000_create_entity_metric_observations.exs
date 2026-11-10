defmodule MetricFlow.Repo.Migrations.CreateEntityMetricObservations do
  use Ecto.Migration

  def change do
    create table(:metric_entities) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :entity_type, :string, null: false
      add :external_id, :string, null: false
      add :parent_entity_id, :bigint
      add :display_name, :string, null: false
      add :published_at, :utc_datetime_usec
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:metric_entities, [:account_id, :provider, :entity_type, :external_id],
             name: :metric_entities_identity
           )

    create unique_index(:metric_entities, [:id, :account_id, :provider])
    create unique_index(:metric_entities, [:id, :account_id])

    execute(
      "ALTER TABLE metric_entities ADD CONSTRAINT metric_entities_parent_scope FOREIGN KEY (parent_entity_id, account_id, provider) REFERENCES metric_entities(id, account_id, provider)",
      "ALTER TABLE metric_entities DROP CONSTRAINT metric_entities_parent_scope"
    )

    create table(:entity_metric_observations) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :entity_id, :bigint, null: false
      add :metric_name, :string, null: false
      add :report_date, :date, null: false
      add :report_timezone, :string, null: false
      add :measurement_kind, :string, null: false
      add :breakdown_type, :string, null: false, default: "total"
      add :breakdown_key, :string, null: false, default: "all"
      add :value, :decimal, null: false
      add :unit, :string, null: false
      add :source_report, :string, null: false
      add :fetched_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end

    execute(
      "ALTER TABLE entity_metric_observations ADD CONSTRAINT entity_observations_account_entity FOREIGN KEY (entity_id, account_id) REFERENCES metric_entities(id, account_id) ON DELETE CASCADE",
      "ALTER TABLE entity_metric_observations DROP CONSTRAINT entity_observations_account_entity"
    )

    create unique_index(
             :entity_metric_observations,
             [
               :account_id,
               :entity_id,
               :metric_name,
               :report_date,
               :report_timezone,
               :measurement_kind,
               :breakdown_type,
               :breakdown_key
             ], name: :entity_observations_identity)

    create index(:entity_metric_observations, [:account_id, :metric_name, :report_date])

    create constraint(:entity_metric_observations, :entity_observations_kind,
             check: "measurement_kind IN ('daily', 'snapshot')"
           )

    create constraint(:entity_metric_observations, :entity_observations_total_key,
             check: "breakdown_type <> 'total' OR breakdown_key = 'all'"
           )

    create table(:entity_metric_cursors) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :entity_id, :bigint, null: false
      add :source_report, :string, null: false
      add :report_timezone, :string, null: false
      add :through_date, :date, null: false
      timestamps(type: :utc_datetime_usec)
    end

    execute(
      "ALTER TABLE entity_metric_cursors ADD CONSTRAINT entity_cursors_account_entity FOREIGN KEY (entity_id, account_id) REFERENCES metric_entities(id, account_id) ON DELETE CASCADE",
      "ALTER TABLE entity_metric_cursors DROP CONSTRAINT entity_cursors_account_entity"
    )

    create unique_index(
             :entity_metric_cursors,
             [:account_id, :entity_id, :source_report, :report_timezone],
             name: :entity_metric_cursors_identity
           )
  end
end
