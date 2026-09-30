defmodule MetricFlowSpex.SuccessfulAuthenticationReturnsUserToPlatformSelectionSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Successful authentication returns user to platform selection", criterion: 562 do
    scenario "Dana successfully authenticates with Google Analytics and returns to platform selection" do
      given_ :user_logged_in_as_owner
      given_ :with_oauth_stub_providers

      when_ "Dana successfully authenticates with Google Analytics", context do
        conn = get(context.owner_conn, "/app/integrations/oauth/callback/google",
          MetricFlowTest.OAuthStub.valid_callback_params())
        {:ok, Map.put(context, :callback_conn, conn)}
      end

      then_ "she is redirected back to platform selection", context do
        assert redirected_to(context.callback_conn) =~ "/app/integrations/connect"
        {:ok, context}
      end
    end
  end
end
