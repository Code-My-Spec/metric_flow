defmodule MetricFlow.Invitations.InvitationNotifierTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Invitations.InvitationNotifier

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp invitation_fixture do
    %Invitation{email: "invitee@example.com"}
  end

  defp account_name, do: "Acme Corp"
  defp acceptance_url, do: "https://app.example.com/invitations/abc123token"

  # ---------------------------------------------------------------------------
  # deliver_invitation/3
  # ---------------------------------------------------------------------------

  describe "deliver_invitation/3" do
    test "sends an email to the recipient address" do
      InvitationNotifier.deliver_invitation(invitation_fixture(), account_name(), acceptance_url())

      assert_email_sent(to: invitation_fixture().email)
    end

    test "sets the subject to include the account name" do
      InvitationNotifier.deliver_invitation(invitation_fixture(), account_name(), acceptance_url())

      assert_email_sent(subject: "You've been invited to #{account_name()}")
    end

    test "includes the acceptance URL in the email body" do
      InvitationNotifier.deliver_invitation(invitation_fixture(), account_name(), acceptance_url())

      assert_email_sent(fn email ->
        assert email.text_body =~ acceptance_url()
      end)
    end

    test "includes the 7-day expiry notice in the email body" do
      InvitationNotifier.deliver_invitation(invitation_fixture(), account_name(), acceptance_url())

      assert_email_sent(fn email ->
        assert email.text_body =~ "7 days"
      end)
    end

    test "returns {:ok, email} when delivery succeeds" do
      assert {:ok, email} =
               InvitationNotifier.deliver_invitation(invitation_fixture(), account_name(), acceptance_url())

      assert %Swoosh.Email{} = email
    end

    test "returns {:error, reason} when the mailer fails" do
      original_config = Application.get_env(:metric_flow, MetricFlow.Mailer)

      Application.put_env(:metric_flow, MetricFlow.Mailer,
        adapter: MetricFlow.Invitations.InvitationNotifierTest.FailingAdapter
      )

      result = InvitationNotifier.deliver_invitation(invitation_fixture(), account_name(), acceptance_url())

      Application.put_env(:metric_flow, MetricFlow.Mailer, original_config)

      assert {:error, :simulated_failure} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Minimal failing adapter used only in the error propagation test above
  # ---------------------------------------------------------------------------

  defmodule FailingAdapter do
    @behaviour Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, :simulated_failure}

    @impl true
    def validate_config(_config), do: :ok
  end
end
