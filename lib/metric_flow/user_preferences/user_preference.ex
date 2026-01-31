defmodule MetricFlow.UserPreferences.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_preferences" do
    belongs_to :active_account, MetricFlow.Accounts.Account, type: :binary_id
    field :token, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_preference, attrs, user_scope) do
    user_preference
    |> cast(attrs, [:active_account_id, :token])
    |> validate_required([])
    |> put_change(:user_id, user_scope.user.id)
  end
end
