defmodule MetricFlowTest.GoogleLoginStub do
  @moduledoc "Google login provider whose strategy replays a canned profile (no network)."
  @behaviour MetricFlow.Integrations.Providers.Behaviour

  defmodule Strategy do
    def authorize_url(config) do
      state = "stub-state-#{System.unique_integer([:positive])}"

      {:ok,
       %{
         url:
           "https://accounts.google.test/auth?state=#{state}&redirect_uri=#{config[:redirect_uri]}",
         session_params: %{state: state}
       }}
    end

    def callback(_config, %{"code" => "good"}),
      do:
        {:ok,
         %{
           user: Application.fetch_env!(:metric_flow, :google_login_stub_user),
           token: %{"access_token" => "t"}
         }}

    def callback(_config, _), do: {:error, :bad_code}
  end

  @impl true
  def config,
    do: [
      client_id: "id",
      client_secret: "secret",
      redirect_uri: "http://localhost/auth/google/callback"
    ]

  @impl true
  def strategy, do: Strategy
  @impl true
  defdelegate normalize_user(data), to: MetricFlow.Integrations.Providers.GoogleLogin
end
