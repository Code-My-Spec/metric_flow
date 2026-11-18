defmodule MetricFlow.Repo.Migrations.CreateOauthTables do
  use Ecto.Migration

  # OAuth authorization server for MCP clients (ex_oauth2_provider schemas),
  # plus the PKCE challenge each authorization code was issued against.
  def change do
    create table(:oauth_applications) do
      add :name, :string, null: false
      add :uid, :string, null: false
      add :secret, :string, null: false, default: ""
      add :redirect_uri, :text, null: false
      add :scopes, :string, null: false, default: ""
      add :owner_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:oauth_applications, [:uid])

    create table(:oauth_access_grants) do
      add :token, :string, null: false
      add :expires_in, :integer, null: false
      add :redirect_uri, :text, null: false
      add :revoked_at, :utc_datetime
      add :scopes, :string
      add :code_challenge, :string
      add :code_challenge_method, :string
      add :resource_owner_id, references(:users, on_delete: :delete_all)
      add :application_id, references(:oauth_applications, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:oauth_access_grants, [:token])

    create table(:oauth_access_tokens) do
      add :token, :string, null: false
      add :refresh_token, :string
      add :expires_in, :integer
      add :revoked_at, :utc_datetime
      add :scopes, :string
      add :previous_refresh_token, :string, null: false, default: ""
      add :resource_owner_id, references(:users, on_delete: :delete_all)
      add :application_id, references(:oauth_applications, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:oauth_access_tokens, [:token])
    create unique_index(:oauth_access_tokens, [:refresh_token])
    create index(:oauth_access_tokens, [:resource_owner_id, :application_id])
  end
end
