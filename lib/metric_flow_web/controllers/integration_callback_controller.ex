defmodule MetricFlowWeb.IntegrationCallbackController do
  @moduledoc """
  Handles legacy OAuth callback GET requests by redirecting to the LiveView
  callback route.

  Some OAuth providers or external links may route the callback to
  `/integrations/callback/:provider`. This controller forwards all query
  parameters to the LiveView-based callback route at
  `/integrations/oauth/callback/:provider`.
  """

  use MetricFlowWeb, :controller

  def callback(conn, %{"provider" => provider} = params) do
    query_params =
      params
      |> Map.drop(["provider"])
      |> URI.encode_query()

    path =
      if query_params == "" do
        "/integrations/oauth/callback/#{provider}"
      else
        "/integrations/oauth/callback/#{provider}?#{query_params}"
      end

    redirect(conn, to: path)
  end
end
