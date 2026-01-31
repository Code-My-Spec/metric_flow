defmodule MetricFlow.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences) do
      add :active_account_id, references(:accounts, on_delete: :nilify_all, type: :uuid)
      add :token, :string
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_preferences, [:user_id])
    create index(:user_preferences, [:active_account_id])
  end
end
