defmodule CodeMySpec.Repo.Migrations.CreateAccountsTable do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :slug, :string
      add :type, :string, null: false, default: "personal"

      timestamps()
    end

    create unique_index(:accounts, [:slug])
    create index(:accounts, [:type])
  end
end
