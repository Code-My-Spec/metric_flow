defmodule MetricFlow.Repo.Migrations.MoveDataOwnershipToAccounts do
  @moduledoc """
  Moves ownership of integrations, sync jobs, sync history, metrics, derived
  metric definitions, dashboards and visualizations from users to accounts.

  * Adds a nullable `account_id` (cascade on account delete) to every table
    that lacks one. `user_id` stays as "created/connected by": it becomes
    nullable and is nilified when the user is deleted, so a member leaving
    never takes the account's data with them.
  * Backfills `account_id` for users who originated exactly one account.
    Sync jobs and history take their integration's account first. Users with
    zero or several originated accounts are left NULL -- see
    `MetricFlow.Release.legacy_ownership_report/0` and
    `MetricFlow.Release.assign_legacy_ownership/2`.
  * Replaces the per-user `(user_id, provider)` integration uniqueness with
    the existing `(account_id, provider)` index for every provider, and the
    per-user derived metric name uniqueness with a per-account one.
  * Drops the unused user-scoped entity metric tables.

  A follow-up migration should make `account_id` NOT NULL once every
  ambiguous user has been assigned.
  """

  use Ecto.Migration

  @new_account_tables [
    :metrics,
    :sync_jobs,
    :sync_history,
    :derived_metric_definitions,
    :dashboards,
    :visualizations
  ]

  @creator_tables [:integrations | @new_account_tables]

  def up do
    for table <- @new_account_tables do
      alter table(table) do
        add :account_id, references(:accounts, on_delete: :delete_all)
      end
    end

    for table <- @creator_tables do
      execute """
      ALTER TABLE #{table}
        DROP CONSTRAINT #{table}_user_id_fkey,
        ADD CONSTRAINT #{table}_user_id_fkey FOREIGN KEY (user_id)
          REFERENCES users(id) ON DELETE SET NULL NOT VALID
      """

      execute "ALTER TABLE #{table} VALIDATE CONSTRAINT #{table}_user_id_fkey"
      execute "ALTER TABLE #{table} ALTER COLUMN user_id DROP NOT NULL"
    end

    # -- Backfill ---------------------------------------------------------

    execute """
    UPDATE integrations AS t
    SET account_id = o.account_id
    FROM (#{sole_originated_accounts_sql()}) AS o
    WHERE t.user_id = o.user_id
      AND t.account_id IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM integrations AS i2
        WHERE i2.account_id = o.account_id AND i2.provider = t.provider
      )
    """

    for table <- [:sync_jobs, :sync_history] do
      execute """
      UPDATE #{table} AS t
      SET account_id = i.account_id
      FROM integrations AS i
      WHERE t.integration_id = i.id
        AND t.account_id IS NULL
        AND i.account_id IS NOT NULL
      """
    end

    for table <- @new_account_tables do
      execute backfill_by_user_sql(table)
    end

    # -- Indexes -------------------------------------------------------------

    drop_if_exists index(:integrations, [:user_id, :provider],
                     name: :integrations_user_id_provider_index
                   )

    drop_if_exists unique_index(:derived_metric_definitions, [:user_id, :name])
    create unique_index(:derived_metric_definitions, [:account_id, :name])
    create index(:derived_metric_definitions, [:user_id])

    create index(:metrics, [:account_id, :provider])
    create index(:metrics, [:account_id, :metric_name, :recorded_at])
    create index(:metrics, [:account_id, :normalized_metric_name])
    create index(:sync_jobs, [:account_id, :status])
    create index(:sync_history, [:account_id, :completed_at])
    create index(:dashboards, [:account_id])
    create index(:visualizations, [:account_id])

    # -- Legacy user-scoped entity metric tables (no callers) ---------------

    execute "DROP TABLE IF EXISTS entity_metric_sync_cursors"
    execute "DROP TABLE IF EXISTS entity_metric_daily_observations"
    execute "DROP TABLE IF EXISTS user_metric_entities"
  end

  def down do
    create_legacy_user_tables()

    drop index(:visualizations, [:account_id])
    drop index(:dashboards, [:account_id])
    drop index(:sync_history, [:account_id, :completed_at])
    drop index(:sync_jobs, [:account_id, :status])
    drop index(:metrics, [:account_id, :normalized_metric_name])
    drop index(:metrics, [:account_id, :metric_name, :recorded_at])
    drop index(:metrics, [:account_id, :provider])
    drop index(:derived_metric_definitions, [:user_id])
    drop unique_index(:derived_metric_definitions, [:account_id, :name])

    # Rows whose creator was deleted after this migration have no user to
    # return to; the user-owned schema cannot represent them.
    for table <- @creator_tables do
      execute "DELETE FROM #{table} WHERE user_id IS NULL"
      execute "ALTER TABLE #{table} ALTER COLUMN user_id SET NOT NULL"

      execute """
      ALTER TABLE #{table}
        DROP CONSTRAINT #{table}_user_id_fkey,
        ADD CONSTRAINT #{table}_user_id_fkey FOREIGN KEY (user_id)
          REFERENCES users(id) ON DELETE CASCADE
      """
    end

    create unique_index(:derived_metric_definitions, [:user_id, :name])

    create unique_index(:integrations, [:user_id, :provider],
             name: :integrations_user_id_provider_index,
             where: "provider <> 'youtube'"
           )

    execute "UPDATE integrations SET account_id = NULL WHERE provider <> 'youtube'"

    for table <- @new_account_tables do
      alter table(table) do
        remove :account_id
      end
    end
  end

  @doc false
  def sole_originated_accounts_sql do
    """
    SELECT originator_user_id AS user_id, min(id) AS account_id
    FROM accounts
    WHERE originator_user_id IS NOT NULL
    GROUP BY originator_user_id
    HAVING count(*) = 1
    """
  end

  @doc false
  def backfill_by_user_sql(table) do
    """
    UPDATE #{table} AS t
    SET account_id = o.account_id
    FROM (#{sole_originated_accounts_sql()}) AS o
    WHERE t.user_id = o.user_id AND t.account_id IS NULL
    """
  end

  defp create_legacy_user_tables do
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
