defmodule CodeMySpec.Repo.Migrations.CreateMembersTable do
  use Ecto.Migration

  def change do
    create table(:members) do
      add :role, :string, null: false, default: "member"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all, type: :uuid), null: false

      timestamps()
    end

    create index(:members, [:user_id])
    create index(:members, [:account_id])
    create index(:members, [:role])

    create unique_index(:members, [:user_id, :account_id],
             name: :members_user_id_account_id_index
           )
  end
end
