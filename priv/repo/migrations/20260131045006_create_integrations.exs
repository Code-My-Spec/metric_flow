defmodule MetricFlow.Repo.Migrations.CreateIntegrations do
  use Ecto.Migration

  def change do
    create table(:integrations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :access_token, :binary, null: false
      add :refresh_token, :binary
      add :expires_at, :utc_datetime_usec, null: false
      add :granted_scopes, {:array, :string}, default: []
      add :provider_metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:integrations, [:user_id, :provider],
             name: :integrations_user_id_provider_index
           )

    create index(:integrations, [:user_id])
    create index(:integrations, [:expires_at])
  end
end
