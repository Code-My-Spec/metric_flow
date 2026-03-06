defmodule MetricFlow.Ai.ChatMessage do
  @moduledoc """
  Ecto schema for individual chat messages within a session.

  Each record represents one turn in a conversation, authored by a user, an AI
  assistant, or the system. Messages are always ordered by inserted_at ascending
  within a session so the conversation can be replayed in chronological order.

  System messages are injected at the start of every conversation to provide the
  LLM with marketing analytics context. Assistant messages are persisted after
  streaming completes and include the final token_count. User messages leave
  token_count as nil.

  A message belongs to exactly one ChatSession and must not be reused across
  sessions. Only an inserted_at timestamp is present — messages are immutable
  once persisted.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Ai.ChatSession

  @roles [:user, :assistant, :system]

  @type t :: %__MODULE__{
          id: integer() | nil,
          chat_session_id: integer() | nil,
          role: :user | :assistant | :system | nil,
          content: String.t() | nil,
          token_count: integer() | nil,
          chat_session: ChatSession.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil
        }

  schema "chat_messages" do
    field :role, Ecto.Enum, values: @roles
    field :content, :string
    field :token_count, :integer

    belongs_to :chat_session, ChatSession

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Creates an Ecto changeset for inserting a new ChatMessage record.

  Casts and validates all permitted fields. Requires chat_session_id, role, and
  content. Content must have a minimum length of 1 (blank strings are rejected).
  Adds an association constraint on chat_session to ensure the referenced session
  exists.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:chat_session_id, :role, :content, :token_count])
    |> validate_required([:chat_session_id, :role, :content])
    |> validate_length(:content, min: 1)
    |> assoc_constraint(:chat_session)
  end
end
