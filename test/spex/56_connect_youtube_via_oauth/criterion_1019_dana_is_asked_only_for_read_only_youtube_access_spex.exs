defmodule MetricFlowSpex.Story56.Criterion1019Spex do
  @moduledoc """
  Story 56, criterion 1019: YouTube consent requests read-only access.
  Observes the authorization URL produced by the real OAuth controller.
  Revenue read access is permitted by the complementary criterion 1042.
  """

  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Dana is asked only for read-only YouTube access", criterion: 1019 do
    scenario "the Google consent request excludes video management and upload" do
      given_(:user_logged_in_as_owner)

      given_ "Dana is choosing a platform to connect", context do
        {:ok, view, _html} = live(context.owner_conn, ~p"/app/integrations/connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Dana starts connecting YouTube", context do
        context.view
        |> element("[data-platform='youtube'] [data-role='connect-button']")
        |> render_click()

        {:ok, context}
      end

      then_ "Google asks for read-only YouTube and Analytics access without write permissions",
            context do
        {oauth_path, _flash} = assert_redirect(context.view)
        assert oauth_path == ~p"/app/integrations/oauth/youtube"

        response = get(context.owner_conn, oauth_path)
        uri = response |> redirected_to() |> URI.parse()
        assert uri.scheme == "https"
        assert uri.host == "accounts.google.com"

        params = URI.decode_query(uri.query || "")
        scopes = MapSet.new(String.split(params["scope"] || ""))
        assert MapSet.member?(scopes, "https://www.googleapis.com/auth/youtube.readonly")
        assert MapSet.member?(scopes, "https://www.googleapis.com/auth/yt-analytics.readonly")

        youtube_scopes =
          Enum.filter(scopes, fn scope ->
            String.starts_with?(scope, "https://www.googleapis.com/auth/youtube") or
              String.starts_with?(scope, "https://www.googleapis.com/auth/yt-analytics")
          end)

        allowed =
          MapSet.new([
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/yt-analytics.readonly",
            "https://www.googleapis.com/auth/yt-analytics-monetary.readonly"
          ])

        assert MapSet.subset?(MapSet.new(youtube_scopes), allowed)
        {:ok, context}
      end
    end
  end
end
