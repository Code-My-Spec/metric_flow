defmodule MetricFlow.Repo.Migrations.AddBreakdownTypeToEntityMetricCursors do
  use Ecto.Migration

  def up do
    alter table(:entity_metric_cursors) do
      add :breakdown_type, :string, null: false, default: "total"
    end

    drop unique_index(
           :entity_metric_cursors,
           [:account_id, :entity_id, :source_report, :report_timezone],
           name: :entity_metric_cursors_identity
         )

    create unique_index(
             :entity_metric_cursors,
             [:account_id, :entity_id, :source_report, :report_timezone, :breakdown_type],
             name: :entity_metric_cursors_identity
           )
  end

  def down do
    execute("DELETE FROM entity_metric_cursors WHERE breakdown_type <> 'total'")

    drop unique_index(
           :entity_metric_cursors,
           [:account_id, :entity_id, :source_report, :report_timezone, :breakdown_type],
           name: :entity_metric_cursors_identity
         )

    alter table(:entity_metric_cursors) do
      remove :breakdown_type
    end

    create unique_index(
             :entity_metric_cursors,
             [:account_id, :entity_id, :source_report, :report_timezone],
             name: :entity_metric_cursors_identity
           )
  end
end
