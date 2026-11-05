defmodule MetricFlowWeb.VerifyController do
  @moduledoc """
  Ask this application to exercise one of its integrations, for real, now.

  Setup provisions the pieces an integration needs — a credential, a socket, a
  bucket — and then has to find out whether they actually work together. It
  cannot do that from outside: the interesting failures are the app's own
  connection, its own key and its own origin, and every one of them can be
  wrong while the configuration that produced them looks right. So it asks the
  app to speak, and reads the result from the far side.

  ## Why this is not test code

  The question it answers is "is this integration working right now", which is
  the question an incident asks. When the widget stops reaching support, this
  is the endpoint that separates a broken socket from a broken browser — and it
  is more useful on a Tuesday afternoon in production than it ever is during
  setup. Test scaffolding exists to make a check pass and bypasses the real
  path to do it; this uses the same client, the same credential and the same
  socket a visitor's traffic uses, which is the entire point.

  ## What it deliberately cannot do

  It makes an integration *speak*. It cannot make the application stop: there
  is no action here that fails a health check, drops a container or takes the
  app out of rotation. An authenticated endpoint that could do that would turn
  the deploy key into a way to take the site down, and that key lives in every
  environment's encrypted env.

  Separate from `/health` for the reason that endpoint's own moduledoc gives:
  the proxy gates the traffic swap on it, so it stays shallow. Anything that
  reaches a dependency belongs here instead, behind the deploy key.
  """

  use MetricFlowWeb, :controller

  require Logger

  plug :authenticate when action != :always_failing

  @doc """
  Always 503. A monitor pointed here is a monitor proving it notices.

  Uptime monitoring is asserted far more often than it is tested, and the way
  it fails is silent: a monitor watching the wrong host, or with no working
  notification target, looks exactly like a monitor watching a healthy site.
  The only way to tell them apart is to give it something that is genuinely
  down and see whether anyone is told.

  Doing that by breaking the application would be the obvious approach and the
  wrong one — it takes real traffic with it, and an endpoint that could do it
  would make the deploy key a way to cause an outage. This route is down
  *by construction* and affects nothing else: no state, no dependency, no
  bearing on `/health` or on whether traffic swaps.

  Unauthenticated on purpose. A monitor will not carry the deploy key, and this
  reveals nothing — it is a constant.
  """
  def always_failing(conn, _params) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{status: "down", by: "design", hint: "a monitor pointed here should alert"})
  end

  @doc """
  Send a message through the support widget's own client.

  The message travels the path a visitor's does — the server-side Slipstream
  client, the project deploy key, the conversation channel — so CodeMySpec
  sees it arrive from this site and can say the widget works without anyone
  having opened a browser.

  Answers 202: the send is asynchronous, and the proof is that the message
  turns up on the other side rather than that this request returned.
  """
  def widget(conn, params) do
    origin = "#{conn.scheme}://#{conn.host}"
    probe = Map.get(params, "probe", "cms-verify-#{System.system_time(:second)}")

    case send_widget_message(probe, origin) do
      :ok ->
        json(conn, %{status: "accepted", integration: "widget", probe: probe, origin: origin})

      {:error, :not_installed} ->
        conn
        |> put_status(:not_implemented)
        |> json(%{
          status: "unavailable",
          integration: "widget",
          reason: "this application does not have the support widget installed"
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{status: "failed", integration: "widget", reason: inspect(reason)})
    end
  end

  # Resolved at runtime rather than aliased, because the widget is generated
  # separately (`mix cms_gen.support_widget`) and an application that has not
  # run it should answer "not installed" rather than fail to compile.
  defp send_widget_message(probe, origin) do
    widget = Module.concat([MetricFlow, CodeMySpec, Widget])

    case Code.ensure_loaded?(widget) do
      false ->
        {:error, :not_installed}

      true ->
        # A stable identity, so repeated verification reuses one conversation
        # instead of opening a new one per run. It is marked as a probe in the
        # address as well as the body: this must not read as a real user's
        # first message to whoever answers support.
        user_id = "cms-verify"
        email = "verify@#{origin |> URI.parse() |> Map.get(:host)}"

        widget.ensure_started(user_id, email, origin)
        widget.send_message(user_id, "#{probe} — automated integration check, no reply needed")

        :ok
    end
  rescue
    error -> {:error, error}
  end

  # The project's deploy key, which this application already holds to talk to
  # CodeMySpec at all. Compared in constant time: a timing oracle on a
  # credential that also authorises content publishing is worth avoiding for
  # the two lines it costs.
  defp authenticate(conn, _opts) do
    with expected when is_binary(expected) and expected != "" <- configured_key(),
         ["Bearer " <> presented] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(presented, expected) do
      conn
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "unauthorized"})
        |> halt()
    end
  end

  defp configured_key, do: Application.get_env(:metric_flow, :deploy_key)
end
