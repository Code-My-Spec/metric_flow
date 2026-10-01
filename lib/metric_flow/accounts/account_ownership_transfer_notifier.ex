defmodule MetricFlow.Accounts.AccountOwnershipTransferNotifier do
  @moduledoc """
  Delivers ownership-transfer emails using Swoosh: the initial transfer
  request (with the confirmation link) and the completion notice sent to
  both the previous and new owner once the transfer is confirmed.
  """

  import Swoosh.Email

  alias MetricFlow.Mailer

  @doc """
  Delivers the transfer request email to the intended new owner, with the
  link they must confirm via to accept ownership.
  """
  @spec deliver_transfer_request(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_transfer_request(recipient_email, account_name, previous_owner_email, confirm_url) do
    deliver_email(recipient_email, "Confirm ownership transfer for #{account_name}", """

    ==============================

    Hi #{recipient_email},

    #{previous_owner_email} wants to transfer ownership of the account
    "#{account_name}" to you on MetricFlow.

    Click the link below to confirm and accept ownership:

    #{confirm_url}

    If you did not expect this, you can safely ignore this email.

    ==============================
    """)
  end

  @doc """
  Delivers the transfer-completed notice to one recipient (called once for
  the previous owner and once for the new owner).
  """
  @spec deliver_transfer_completed(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_transfer_completed(recipient_email, account_name, previous_owner_email, new_owner_email) do
    deliver_email(recipient_email, "Ownership of #{account_name} has transferred", """

    ==============================

    Hi #{recipient_email},

    Ownership of the account "#{account_name}" has transferred from
    #{previous_owner_email} to #{new_owner_email}.

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
