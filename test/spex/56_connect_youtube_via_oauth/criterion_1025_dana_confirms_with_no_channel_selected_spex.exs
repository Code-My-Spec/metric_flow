defmodule MetricFlowSpex.Story56.Criterion1025Spex do
  @moduledoc """
  Story 56, criterion 1025: selecting at least one channel is required.
  Drives OAuth and the real selection form; observes persistence through UI.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana confirms with no channel selected", criterion: 1025 do
    scenario "an empty selection shows validation and saves no integration" do
      given_(:user_logged_in_as_owner)

      given_ "Dana has signed in to YouTube and sees her available channels", context do
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

      when_ "Dana confirms without selecting any channel", context do
        context.selection
        |> form("[data-role='account-selection']", %{"channel_ids" => []})
        |> render_submit()

        {:ok, context}
      end

      then_ "she is told to select at least one channel", context do
        assert has_element?(context.selection, "[data-role='account-selection']")
        assert has_element?(context.selection, "[role='alert']", ~r/select at least one channel/i)
        assert has_element?(context.selection, "[data-role='account-option']", "Dana Personal")
        {:ok, context}
      end

      then_ "no YouTube integration is saved", context do
        {:ok, integrations, _html} = live(context.conn, ~p"/app/integrations")
        assert has_element?(integrations, "[data-role='integrations-index']")

        refute has_element?(
                 integrations,
                 "[data-role='integrations-list'] [data-role='integration-card'][data-platform='youtube']"
               )

        {:ok, platforms, _html} = live(context.conn, ~p"/app/integrations/connect")

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
