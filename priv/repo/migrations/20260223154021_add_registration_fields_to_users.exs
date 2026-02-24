defmodule MetricFlow.Repo.Migrations.AddRegistrationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :account_name, :string
      add :account_type, :string
    end
  end
end
