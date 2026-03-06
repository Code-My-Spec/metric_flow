defmodule MetricFlow.Ai.ChatSession do
  @moduledoc """
  Ecto schema representing a conversational AI chat session.

  Each session belongs to a user and an account, and may optionally be scoped
  to a specific correlation result, metric, or dashboard so the assistant has
  focused context for its responses.

  Sessions begin in the :active state and can be moved to :archived by the
  user. There is no transition back to :active — archiving is irreversible.

  Has many ChatMessages. Messages are ordered by inserted_at ascending at
  query time to preserve conversation chronology.

  State transitions for status:
  - :active -> :archived (user archives the session; no path back to :active)

  Business rules:
  - context_id must be nil when context_type is :general
  - context_id may be set when context_type is :correlation, :metric, or :dashboard
  - title is optional at creation; expected to be set after the first user message
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Ai.ChatMessage
  alias MetricFlow.Users.User

  @context_types [:general, :correlation, :metric, :dashboard]
  @statuses [:active, :archived]

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          account_id: integer() | nil,
          title: String.t() | nil,
          context_type: :general | :correlation | :metric | :dashboard | nil,
          context_id: integer() | nil,
          status: :active | :archived,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          chat_messages: list(ChatMessage.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "chat_sessions" do
    field :title, :string
    field :context_type, Ecto.Enum, values: @context_types
    field :context_id, :integer
    field :status, Ecto.Enum, values: @statuses, default: :active

    belongs_to :user, User
    belongs_to :account, Account
    has_many :chat_messages, ChatMessage

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a ChatSession record.

  Casts and validates all permitted fields. Status defaults to :active when
  not provided. Adds association constraints on user and account foreign keys.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(chat_session, attrs) do
    chat_session
    |> cast(attrs, [:user_id, :account_id, :title, :context_type, :context_id, :status])
    |> validate_required([:user_id, :account_id, :context_type])
    |> validate_length(:title, max: 255)
    |> assoc_constraint(:user)
    |> assoc_constraint(:account)
  end

  @doc """
  Creates an Ecto changeset that transitions a ChatSession from :active to
  :archived.

  Validates the session is currently :active before applying the transition.
  Returns an invalid changeset with an error on :status when the session is
  already :archived.
  """
  @spec archive_changeset(t()) :: Ecto.Changeset.t()
  def archive_changeset(%__MODULE__{} = chat_session) do
    chat_session
    |> change()
    |> validate_status_is_active()
    |> put_change(:status, :archived)
  end

  defp validate_status_is_active(%Ecto.Changeset{data: %__MODULE__{status: :active}} = changeset) do
    changeset
  end

  defp validate_status_is_active(changeset) do
    add_error(changeset, :status, "must be active to archive")
  end
end
