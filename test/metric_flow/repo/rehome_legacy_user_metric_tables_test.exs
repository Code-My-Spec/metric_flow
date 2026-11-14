defmodule MetricFlow.Repo.Migrations.RehomeLegacyUserMetricTablesTest do
  use MetricFlowTest.DataCase, async: false

  @migration MetricFlow.Repo.Migrations.RehomeLegacyUserMetricTables

  unless Code.ensure_loaded?(@migration) do
    Code.require_file(
      Path.expand(
        "../../../priv/repo/migrations/20261016000000_rehome_legacy_user_metric_tables.exs",
        __DIR__
      )
    )
  end

  test "relocates legacy user tables without replacing existing account tables" do
    sql!("SET LOCAL search_path TO pg_temp")

    sql!("""
    CREATE TEMP TABLE metric_entities (
      id bigserial PRIMARY KEY, user_id bigint, provider text, entity_id text,
      display_name text, metadata jsonb, inserted_at timestamp, updated_at timestamp
    ) ON COMMIT DROP
    """)

    sql!("""
    CREATE TEMP TABLE user_metric_entities (
      id bigserial PRIMARY KEY, user_id bigint, provider text, entity_id text,
      display_name text, metadata jsonb, inserted_at timestamp, updated_at timestamp
    ) ON COMMIT DROP
    """)

    sql!("""
    INSERT INTO metric_entities (user_id, provider, entity_id, display_name, metadata, inserted_at, updated_at)
    VALUES (42, 'youtube', 'channel-1', 'Old channel', '{}', now(), now())
    """)

    sql!("""
    CREATE TEMP TABLE entity_metric_cursors (
      id bigserial PRIMARY KEY, user_id bigint, provider text, entity_id text,
      metric_name text, synced_through date, inserted_at timestamp, updated_at timestamp
    ) ON COMMIT DROP
    """)

    sql!("""
    INSERT INTO entity_metric_cursors (user_id, provider, entity_id, metric_name, synced_through, inserted_at, updated_at)
    VALUES (42, 'youtube', 'channel-1', 'views', '2026-11-01', now(), now())
    """)

    sql!(
      "CREATE TEMP TABLE entity_metric_observations (id bigserial PRIMARY KEY, account_id bigint) ON COMMIT DROP"
    )

    Enum.each(apply(@migration, :statements, []), &sql!/1)

    assert [[42, "Old channel"]] =
             sql!("SELECT user_id, display_name FROM user_metric_entities").rows

    assert [[42, "Old channel"]] =
             sql!("SELECT user_id, display_name FROM legacy_user_metric_entities").rows

    assert [[42, "views"]] =
             sql!("SELECT user_id, metric_name FROM entity_metric_sync_cursors").rows

    assert [["entity_metric_observations"]] =
             sql!(
               "SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'entity_metric_observations'"
             ).rows

    assert [[nil]] = sql!("SELECT to_regclass('metric_entities')").rows
    assert [[nil]] = sql!("SELECT to_regclass('entity_metric_cursors')").rows
  end

  defp sql!(statement), do: Ecto.Adapters.SQL.query!(Repo, statement, [])
end
