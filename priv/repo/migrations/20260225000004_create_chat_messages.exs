defmodule MetricFlow.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :chat_session_id, references(:chat_sessions, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :token_count, :integer

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:chat_messages, [:chat_session_id])
    create index(:chat_messages, [:chat_session_id, :inserted_at])
  end
end
