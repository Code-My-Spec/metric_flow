defmodule MetricFlow.Repo.Migrations.CreateChatSessions do
  use Ecto.Migration

  def change do
    create table(:chat_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :title, :string
      add :context_type, :string, null: false
      add :context_id, :integer
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:chat_sessions, [:user_id])
    create index(:chat_sessions, [:account_id])
    create index(:chat_sessions, [:user_id, :status])
  end
end
