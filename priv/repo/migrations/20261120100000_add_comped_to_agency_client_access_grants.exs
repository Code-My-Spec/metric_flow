defmodule MetricFlow.Repo.Migrations.AddCompedToAgencyClientAccessGrants do
  use Ecto.Migration

  def change do
    alter table(:agency_client_access_grants) do
      add :comped, :boolean, null: false, default: false
    end
  end
end
