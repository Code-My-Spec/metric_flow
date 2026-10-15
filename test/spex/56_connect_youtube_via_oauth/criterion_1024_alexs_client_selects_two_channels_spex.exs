defmodule MetricFlowSpex.Story56.Criterion1024Spex do
  @moduledoc """
  Story 56, criterion 1024: Jordan selects two channels and sees both saved.
  Persistence is observed by reopening channel selection through the web UI.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Alex's client selects two channels", criterion: 1024 do
    scenario "Jordan saves both channels on the YouTube integration" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan signs in to a Google account managing two channels", context do
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

        callback =
          request
          |> recycle()
          |> get(~p"/app/integrations/oauth/callback/youtube", %{
            "code" => "synthetic-youtube-code",
            "state" => Map.fetch!(params, "state")
          })

        conn = recycle(callback)
        {:ok, selection, _html} = live(conn, redirected_to(callback))
        {:ok, Map.merge(context, %{conn: conn, selection: selection})}
      end

      when_ "Jordan selects both channels and confirms", context do
        context.selection
        |> form("[data-role='account-selection']", %{
          "channel_ids" => ["UC_dana_personal", "UC_dana_brand"]
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "Jordan sees that two channels are connected", context do
        {:ok, integrations, _html} = live(context.conn, ~p"/app/integrations")

        assert has_element?(
                 integrations,
                 "[data-role='integration-card'][data-platform='youtube'][data-status='connected']",
                 ~r/2 channels? connected/i
               )

        {:ok, context}
      end

      then_ "both channel selections remain saved when reopened", context do
        {:ok, selection, _html} =
          live(context.conn, ~p"/app/integrations/connect/youtube/accounts")

        assert has_element?(selection, "[data-role='account-selection']")

        assert has_element?(
                 selection,
                 "[data-role='account-checkbox'][value='UC_dana_personal']:checked"
               )

        assert has_element?(
                 selection,
                 "[data-role='account-checkbox'][value='UC_dana_brand']:checked"
               )

        {:ok, context}
      end
    end
  end
end
