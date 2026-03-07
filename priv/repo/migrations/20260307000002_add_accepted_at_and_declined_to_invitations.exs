defmodule MetricFlow.Repo.Migrations.AddAcceptedAtAndDeclinedToInvitations do
  use Ecto.Migration

  def change do
    # accepted_at was already added in 20260307000001_create_invitations.exs.
    # The :declined status value is handled at the application level via Ecto.Enum
    # and requires no schema change since status is stored as a plain string column.
    :ok
  end
end
