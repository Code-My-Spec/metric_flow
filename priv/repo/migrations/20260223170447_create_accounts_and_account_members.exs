defmodule MetricFlow.Repo.Migrations.CreateAccountsAndAccountMembers do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :type, :string, null: false
      add :originator_user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:accounts, [:slug])
    create index(:accounts, [:originator_user_id])

    create table(:account_members) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:account_members, [:account_id, :user_id])
    create index(:account_members, [:user_id])
  end
end
