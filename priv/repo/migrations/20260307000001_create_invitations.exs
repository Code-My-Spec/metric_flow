defmodule MetricFlow.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations) do
      add :token_hash, :binary, null: false
      add :email, :string, null: false
      add :role, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :invited_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invitations, [:token_hash])
    create index(:invitations, [:account_id])
    create index(:invitations, [:email])
  end
end
