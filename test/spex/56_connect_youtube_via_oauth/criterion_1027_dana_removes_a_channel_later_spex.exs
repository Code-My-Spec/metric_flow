defmodule MetricFlowSpex.Story56.Criterion1027Spex do
  @moduledoc """
  Story 56, criterion 1027: removing a channel updates the saved sync
  selection without another sign-in. Observes the selection after reload.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana removes a channel later", criterion: 1027 do
    scenario "only the remaining channel stays selected for syncing" do
      given_(:user_logged_in_as_owner)

      given_ "Dana has YouTube connected with two channels", context do
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

        selection
        |> form("[data-role='account-selection']", %{
          "channel_ids" => ["UC_dana_personal", "UC_dana_brand"]
        })
        |> render_submit()

        {:ok, existing, _html} = live(conn, ~p"/app/integrations/connect/youtube/accounts")
        {:ok, Map.merge(context, %{conn: conn, existing: existing})}
      end

      when_ "Dana deselects her brand channel and saves", context do
        context.existing
        |> form("[data-role='account-selection']", %{"channel_ids" => ["UC_dana_personal"]})
        |> render_submit()

        {:ok, context}
      end

      then_ "only her personal channel remains selected without another sign-in", context do
        {:ok, selection, _html} =
          live(context.conn, ~p"/app/integrations/connect/youtube/accounts")

        assert has_element?(selection, "[data-role='account-selection']")

        assert has_element?(
                 selection,
                 "[data-role='account-checkbox'][value='UC_dana_personal']:checked"
               )

        assert has_element?(
                 selection,
                 "[data-role='account-checkbox'][value='UC_dana_brand']:not(:checked)"
               )

        refute has_element?(selection, "[data-role='oauth-connect-button']")

        {:ok, integrations, _html} = live(context.conn, ~p"/app/integrations")

        assert has_element?(
                 integrations,
                 "[data-role='integration-card'][data-platform='youtube'][data-status='connected']",
                 ~r/1 channel connected/i
               )

        {:ok, context}
      end
    end
  end
end
