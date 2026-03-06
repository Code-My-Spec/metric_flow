defmodule MetricFlow.Repo.Migrations.CreateAgencyClientAccessGrants do
  use Ecto.Migration

  def change do
    create table(:agency_client_access_grants) do
      add :agency_account_id, references(:accounts, on_delete: :delete_all), null: false
      add :client_account_id, references(:accounts, on_delete: :delete_all), null: false
      add :access_level, :string, null: false
      add :origination_status, :string, null: false, default: "invited"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:agency_client_access_grants, [:agency_account_id, :client_account_id])
    create index(:agency_client_access_grants, [:agency_account_id])
    create index(:agency_client_access_grants, [:client_account_id])
  end
end
