defmodule MetricFlow.Invitations.InvitationNotifier do
  @moduledoc """
  Delivers invitation emails to recipients using Swoosh.

  Accepts the invitation struct, the inviting account name string, and the
  pre-built acceptance URL. The raw token is never stored — only its hash is
  persisted in the database.
  """

  import Swoosh.Email

  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Mailer

  @doc """
  Delivers an invitation email to the recipient.

  Accepts the invitation struct, the account name to include in the email body,
  and the fully-built acceptance URL string. Returns `{:ok, email}` on successful
  delivery.
  """
  @spec deliver_invitation(Invitation.t(), String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_invitation(%Invitation{email: email}, account_name, acceptance_url)
      when is_binary(acceptance_url) do
    deliver_email(email, "You've been invited to #{account_name}", """

    ==============================

    Hi #{email},

    You have been invited to join #{account_name} on MetricFlow.

    Click the link below to accept your invitation:

    #{acceptance_url}

    This invitation expires in 7 days.

    If you did not expect this invitation, please ignore this email.

    ==============================
    """)
  end

  defp deliver_email(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MetricFlow", "noreply@metric-flow.app"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
