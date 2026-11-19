defmodule MetricFlow.InviteClientToolTest do
  use MetricFlowTest.DataCase, async: false

  import Swoosh.TestAssertions
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Onboarding.Tools

  test "invite-client-tool-2: criterion 1 - invite_client returns the signup link and emails it naming the agency" do
    joel = user_fixture()
    agency = account_with_member_fixture(joel, :owner)

    assert {:ok, %{url: url, emailed: true}} =
             Tools.call(:mcp, "invite_client", %{"email" => "jane@acme.com"}, %{user: joel})

    assert url =~ "/users/register?ref="

    assert_email_sent(fn email ->
      assert email.to == [{"", "jane@acme.com"}]
      assert email.text_body =~ url
      assert email.text_body =~ agency.name
    end)

    # exactly one email: the one asserted above has been consumed
    refute_email_sent()
  end
end
