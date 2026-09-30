defmodule MetricFlowSpex.UserReceivesEmailNotificationAboutExpiredCredentialsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User receives email notification about expired credentials", criterion: 124 do
    scenario "an integration entering Needs Reconnection status emails the user" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's credentials expire", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the user views the integrations dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user has received an email about the expired credentials", context do
        assert_receive {:email, email}, 500
        assert email.to == [{"", context.owner_email}]

        assert email.subject =~ "expired" or email.subject =~ "reconnect" or
                 email.subject =~ "Reconnect"

        {:ok, context}
      end
    end
  end
end
