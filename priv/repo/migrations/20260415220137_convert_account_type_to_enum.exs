defmodule MetricFlow.Repo.Migrations.ConvertAccountTypeToEnum do
  use Ecto.Migration

  def up do
    # Convert existing personal/team accounts to client
    execute "UPDATE accounts SET type = 'client' WHERE type IN ('personal', 'team')"

    execute "CREATE TYPE account_type AS ENUM ('client', 'agency')"

    execute """
    ALTER TABLE accounts
      ALTER COLUMN type TYPE account_type USING type::account_type
    """
  end

  def down do
    execute """
    ALTER TABLE accounts
      ALTER COLUMN type TYPE varchar(255) USING type::text
    """

    execute "DROP TYPE account_type"
  end
end
