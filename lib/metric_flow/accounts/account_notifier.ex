defmodule MetricFlow.Accounts.AccountNotifier do
  @moduledoc """
  Delivers account-lifecycle emails (e.g. deletion confirmation) using Swoosh.
  """

  import Swoosh.Email

  alias MetricFlow.Mailer

  @doc """
  Delivers a confirmation email to the owner after an account is deleted.

  Accepts the owner's email and the deleted account's name. Returns
  `{:ok, email}` on successful delivery.
  """
  @spec deliver_account_deletion_confirmation(String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_account_deletion_confirmation(owner_email, account_name) do
    deliver_email(owner_email, "Your account \"#{account_name}\" has been deleted", """

    ==============================

    Hi #{owner_email},

    This confirms that the account "#{account_name}" has been permanently deleted,
    along with all of its data, members, and integrations.

    If you did not request this deletion, please contact support immediately.

    ==============================
    """)
  end

  @doc """
  Delivers a notification to the account owner when a member revokes their own
  access (leaves the account).

  Accepts the owner's email, the account's name, and the leaving member's
  email. Returns `{:ok, email}` on successful delivery.
  """
  @spec deliver_self_revoke_notification(String.t(), String.t(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_self_revoke_notification(owner_email, account_name, leaving_member_email) do
    deliver_email(owner_email, "#{leaving_member_email} has left \"#{account_name}\"", """

    ==============================

    Hi #{owner_email},

    #{leaving_member_email} has revoked their own access to "#{account_name}" and is
    no longer a member of this account.

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
