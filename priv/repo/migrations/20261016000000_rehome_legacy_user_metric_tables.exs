defmodule MetricFlow.Repo.Migrations.RehomeLegacyUserMetricTables do
  use Ecto.Migration

  @tables [
    {"metric_entities", "user_metric_entities",
     "user_id, provider, entity_id, display_name, metadata, inserted_at, updated_at"},
    {"entity_metric_observations", "entity_metric_daily_observations",
     "user_id, provider, entity_id, metric_name, observed_on, value, inserted_at, updated_at"},
    {"entity_metric_cursors", "entity_metric_sync_cursors",
     "user_id, provider, entity_id, metric_name, synced_through, inserted_at, updated_at"}
  ]

  def up do
    Enum.each(statements(), &execute/1)
  end

  # The SQL is also exercised against isolated temporary tables in the migration test.
  def statements do
    for {legacy, target, columns} <- @tables do
      backup = "legacy_user_#{legacy}"

      """
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema()
            AND table_name = '#{legacy}'
            AND column_name = 'user_id'
        ) THEN
          IF to_regclass('#{target}') IS NULL THEN
            ALTER TABLE #{legacy} RENAME TO #{target};
            ALTER INDEX IF EXISTS #{legacy}_pkey RENAME TO #{target}_pkey;
            ALTER SEQUENCE IF EXISTS #{legacy}_id_seq RENAME TO #{target}_id_seq;
          ELSE
            INSERT INTO #{target} (#{columns})
            SELECT #{columns} FROM #{legacy}
            ON CONFLICT DO NOTHING;
            ALTER TABLE #{legacy} RENAME TO #{backup};
            ALTER INDEX IF EXISTS #{legacy}_pkey RENAME TO #{backup}_pkey;
            ALTER SEQUENCE IF EXISTS #{legacy}_id_seq RENAME TO #{backup}_id_seq;
          END IF;
        END IF;
      END $$;
      """
    end
  end

  def down do
    raise "Legacy user metric table relocation cannot be reversed without risking account metric data"
  end
end
