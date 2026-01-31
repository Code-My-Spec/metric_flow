defmodule MetricFlow.Repo.Migrations.CreateInvitationsTable do
  use Ecto.Migration

  def change do
    create table(:invitations) do
      add :token, :string, null: false
      add :email, :string, null: false
      add :role, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :account_id, references(:accounts, on_delete: :delete_all, type: :uuid), null: false
      add :invited_by_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:invitations, [:email, :account_id],
             where: "accepted_at IS NULL AND cancelled_at IS NULL",
             name: :unique_account_email_when_nulls
           )

    create unique_index(:invitations, [:token])
    create index(:invitations, [:account_id])
    create index(:invitations, [:email])
    create index(:invitations, [:expires_at])
  end
end
