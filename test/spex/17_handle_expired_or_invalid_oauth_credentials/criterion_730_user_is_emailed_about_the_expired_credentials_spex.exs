defmodule MetricFlowSpex.UserIsEmailedAboutTheExpiredCredentialsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User is emailed about the expired credentials", criterion: 730 do
    scenario "an integration entering Needs Reconnection status triggers an email to the user" do
      given_(:user_logged_in_as_owner)

      when_ "an integration enters Needs Reconnection status", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user receives an email notification about the expired credentials", context do
        assert_receive {:email, email}, 500
        assert email.to == [{"", context.owner_email}]
        {:ok, context}
      end
    end
  end
end
