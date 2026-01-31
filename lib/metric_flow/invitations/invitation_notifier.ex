defmodule MetricFlow.Invitations.InvitationNotifier do
  import Swoosh.Email

  alias MetricFlow.Mailer
  alias MetricFlow.Invitations.Invitation

  def deliver_invitation_email(%Invitation{} = invitation, url) do
    deliver(
      invitation.email,
      "You're invited to join #{invitation.account.name}",
      """
      Hi there,

      You've been invited to join #{invitation.account.name} on MetricFlow.

      Click the link below to accept your invitation:
      #{url}

      This invitation will expire in 7 days.

      If you didn't expect this invitation, you can safely ignore this email.

      Best regards,
      The MetricFlow Team
      """
    )
  end

  def deliver_invitation_reminder(%Invitation{} = invitation, url) do
    deliver(
      invitation.email,
      "Reminder: Your invitation to #{invitation.account.name} is expiring soon",
      """
      Hi there,

      This is a friendly reminder that your invitation to join #{invitation.account.name} on MetricFlow is expiring soon.

      Click the link below to accept your invitation:
      #{url}

      Don't miss out on joining the team!

      Best regards,
      The MetricFlow Team
      """
    )
  end

  def deliver_invitation_cancelled(%Invitation{} = invitation) do
    deliver(
      invitation.email,
      "Your invitation to #{invitation.account.name} has been cancelled",
      """
      Hi there,

      Your invitation to join #{invitation.account.name} on MetricFlow has been cancelled.

      If you have any questions, please contact the account administrator.

      Best regards,
      The MetricFlow Team
      """
    )
  end

  def deliver_welcome_email(user, account) do
    deliver(
      user.email,
      "Welcome to #{account.name}!",
      """
      Hi #{user.email},

      Welcome to #{account.name} on MetricFlow!

      You've successfully accepted your invitation and are now a member of the team.

      You can now access your account and start collaborating.

      Best regards,
      The MetricFlow Team
      """
    )
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MetricFlow", "contact@MetricFlow.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
