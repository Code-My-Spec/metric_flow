defmodule MetricFlow.Repo.Migrations.CreateAutoEnrollmentRules do
  use Ecto.Migration

  def change do
    create table(:auto_enrollment_rules) do
      add :agency_id, references(:accounts, on_delete: :delete_all), null: false
      add :email_domain, :string, null: false
      add :default_access_level, :string, null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:auto_enrollment_rules, [:agency_id, :email_domain])
    create index(:auto_enrollment_rules, [:agency_id])
  end
end
