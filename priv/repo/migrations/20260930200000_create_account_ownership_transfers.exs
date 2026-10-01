defmodule MetricFlow.Repo.Migrations.CreateAccountOwnershipTransfers do
  use Ecto.Migration

  def change do
    create table(:account_ownership_transfers) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :initiated_by_user_id, references(:users, on_delete: :nilify_all)
      add :initiated_by_email, :string, null: false
      add :target_user_id, references(:users, on_delete: :nilify_all)
      add :target_email, :string, null: false
      add :token_hash, :binary, null: false
      add :status, :string, null: false, default: "pending"
      add :remain_admin, :boolean, null: false, default: false
      add :make_copy, :boolean, null: false, default: false
      add :transfer_originator, :boolean, null: false, default: false
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:account_ownership_transfers, [:account_id])
    create unique_index(:account_ownership_transfers, [:token_hash])
  end
end
