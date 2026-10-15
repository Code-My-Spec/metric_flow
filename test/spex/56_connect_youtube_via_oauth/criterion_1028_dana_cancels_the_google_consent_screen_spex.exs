defmodule MetricFlowSpex.Story56.Criterion1028Spex do
  @moduledoc """
  Story 56, criterion 1028: cancelling Google consent explains that YouTube
  was not connected and leaves no saved integration.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana cancels the Google consent screen", criterion: 1028 do
    scenario "denied consent returns a clear message without saving YouTube" do
      given_(:user_logged_in_as_owner)

      given_ "Dana starts connecting YouTube", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/integrations/connect")

        view
        |> element("[data-platform='youtube'] [data-role='connect-button']")
        |> render_click()

        request = get(context.owner_conn, assert_redirect(view))

        params =
          request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok,
         Map.merge(context, %{
           oauth_conn: recycle(request),
           oauth_state: Map.fetch!(params, "state")
         })}
      end

      when_ "Dana cancels on Google's consent screen", context do
        callback =
          get(context.oauth_conn, ~p"/app/integrations/oauth/callback/youtube", %{
            "error" => "access_denied",
            "state" => context.oauth_state
          })

        {:ok, Map.put(context, :callback, callback)}
      end

      then_ "she sees a clear message that YouTube was not connected", context do
        {:ok, view, _html} = live(recycle(context.callback), redirected_to(context.callback))

        assert has_element?(
                 view,
                 "[role='alert']",
                 ~r/YouTube.*(not connected|cancelled|canceled|denied)/i
               )

        {:ok, context}
      end

      then_ "no YouTube integration is saved", context do
        conn = recycle(context.callback)
        {:ok, integrations, _html} = live(conn, ~p"/app/integrations")
        assert has_element?(integrations, "[data-role='integrations-index']")

        refute has_element?(
                 integrations,
                 "[data-role='integration-card'][data-platform='youtube']"
               )

        {:ok, platforms, _html} = live(conn, ~p"/app/integrations/connect")

        assert has_element?(
                 platforms,
                 "[data-platform='youtube'] [data-role='connect-button']",
                 "Connect"
               )

        refute has_element?(
                 platforms,
                 "[data-platform='youtube'] [data-role='connect-button']",
                 "Reconnect"
               )

        {:ok, context}
      end
    end
  end
end
