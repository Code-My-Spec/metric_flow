defmodule MetricFlowSpex.Story56.Criterion1022Spex do
  @moduledoc """
  Story 56, criterion 1022: personal and brand channels are listed by name
  after YouTube sign-in. Only external Google HTTP responses are simulated.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana sees all the channels she manages", criterion: 1022 do
    scenario "both personal and brand channels appear after the OAuth callback" do
      given_(:user_logged_in_as_owner)

      given_ "Dana's Google account manages a personal channel and a brand channel", context do
        originals =
          for key <- [:oauth_providers, :req_http_options],
              do: {key, Application.fetch_env(:metric_flow, key)}

        on_exit(fn ->
          for {key, value} <- originals do
            case value do
              {:ok, original} -> Application.put_env(:metric_flow, key, original)
              :error -> Application.delete_env(:metric_flow, key)
            end
          end
        end)

        Application.put_env(:metric_flow, :oauth_providers, %{
          youtube: MetricFlowTest.YouTubeOAuthProvider
        })

        Application.put_env(:metric_flow, :req_http_options,
          plug: &MetricFlowTest.YouTubeOAuthProvider.respond/1
        )

        request = get(context.owner_conn, ~p"/app/integrations/oauth/youtube")

        params =
          request |> redirected_to() |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok,
         Map.merge(context, %{
           oauth_conn: recycle(request),
           oauth_state: Map.fetch!(params, "state")
         })}
      end

      when_ "Dana finishes signing in to YouTube", context do
        callback =
          get(context.oauth_conn, ~p"/app/integrations/oauth/callback/youtube", %{
            "code" => "synthetic-youtube-code",
            "state" => context.oauth_state
          })

        {:ok, Map.put(context, :callback, callback)}
      end

      then_ "both channels are listed by name for selection", context do
        {:ok, view, _html} = live(recycle(context.callback), redirected_to(context.callback))

        assert has_element?(view, "[data-role='account-selection']")
        assert has_element?(view, "[data-role='account-option']", "Dana Personal")
        assert has_element?(view, "[data-role='account-option']", "Dana Brand")

        assert has_element?(
                 view,
                 "[data-role='account-checkbox'][type='checkbox'][value='UC_dana_personal']"
               )

        assert has_element?(
                 view,
                 "[data-role='account-checkbox'][type='checkbox'][value='UC_dana_brand']"
               )

        {:ok, context}
      end
    end
  end
end
