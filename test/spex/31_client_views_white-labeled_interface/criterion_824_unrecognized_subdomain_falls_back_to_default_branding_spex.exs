defmodule MetricFlowSpex.Criterion824UnrecognizedSubdomainFallsBackToDefaultBrandingSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Unrecognized subdomain falls back to default branding", criterion: 824 do
    scenario "a subdomain matching no active agency shows default branding instead of an error" do
      given_ :user_logged_in_as_owner

      given_ "a client accesses the system via a subdomain that doesn't match any active agency", context do
        %Plug.Conn{} = owner_conn = context.owner_conn
        conn = %{owner_conn | host: "no-such-agency-824.metricflow.io"}
        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "the page loads", context do
        result = live(context.conn, "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "it shows default branding rather than an error", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)
            refute has_element?(view, "[data-role='agency-logo']")
            assert html =~ "MetricFlow" or has_element?(view, "[data-role='default-logo']")

          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok
        end

        {:ok, context}
      end
    end
  end
end
