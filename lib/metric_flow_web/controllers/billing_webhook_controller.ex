defmodule MetricFlowWeb.BillingWebhookController do
  @moduledoc """
  Stripe webhook endpoint handler.

  Receives and verifies Stripe webhook events using signature verification,
  then delegates to the Billing context for subscription lifecycle sync.
  Does not require user authentication — secured by Stripe webhook signing secret.
  """

  use MetricFlowWeb, :controller

  require Logger

  alias MetricFlow.Billing
  alias MetricFlow.Billing.StripeClient

  @doc """
  Handle incoming Stripe webhook events.

  Verifies the webhook signature, parses the event, and delegates processing.
  Returns 200 for successfully processed or acknowledged events.
  Returns 400 for verification failures or malformed payloads.
  """
  @spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def handle(conn, _params) do
    with {:ok, raw_body} <- read_raw_body(conn),
         signature <- get_stripe_signature(conn),
         {:ok, event} <- verify_event(raw_body, signature) do
      process_event(conn, event)
    else
      {:error, :missing_signature} ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing Stripe-Signature header"})

      {:error, :signature_mismatch} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid signature"})

      {:error, :invalid_json} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid JSON payload"})

      {:error, :invalid_signature_format} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid signature format"})

      {:error, :no_body} ->
        conn
        |> put_status(400)
        |> json(%{error: "Empty request body"})
    end
  end

  defp read_raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil ->
        case Plug.Conn.read_body(conn) do
          {:ok, body, _conn} when byte_size(body) > 0 -> {:ok, body}
          {:ok, "", _conn} -> {:error, :no_body}
          {:error, _} -> {:error, :no_body}
        end

      raw_body ->
        {:ok, raw_body}
    end
  end

  defp get_stripe_signature(conn) do
    case Plug.Conn.get_req_header(conn, "stripe-signature") do
      [signature | _] -> signature
      [] -> nil
    end
  end

  defp verify_event(raw_body, signature) do
    platform_secret = Application.get_env(:metric_flow, :stripe_webhook_secret, "")

    case StripeClient.verify_webhook_signature(raw_body, signature, platform_secret) do
      {:ok, event} ->
        {:ok, event}

      {:error, :signature_mismatch} ->
        # Connect events (from agencies' connected accounts) arrive through
        # a separate endpoint secret from the platform's own — try it before
        # giving up, rather than assuming every event is a direct/platform one.
        case Application.get_env(:metric_flow, :stripe_connect_webhook_secret) do
          nil -> {:error, :signature_mismatch}
          connect_secret -> StripeClient.verify_webhook_signature(raw_body, signature, connect_secret)
        end

      other ->
        other
    end
  end

  defp process_event(conn, event) do
    event_id = event["id"]
    event_type = event["type"]

    Logger.info("Processing Stripe webhook: #{event_type} (#{event_id})")

    case Billing.process_webhook_event(event) do
      :ok ->
        conn |> put_status(200) |> json(%{received: true})

      {:ok, :ignored} ->
        conn |> put_status(200) |> json(%{received: true, ignored: true})

      {:ok, :duplicate} ->
        conn |> put_status(200) |> json(%{received: true, duplicate: true})

      {:error, :unrecognized_account} ->
        conn
        |> put_status(400)
        |> json(%{error: "Event references an unrecognized connected account"})

      {:error, reason} ->
        # A non-2xx here is what makes Stripe retry: silently returning 200
        # on a persistence failure means the event is never seen again and
        # local state permanently disagrees with Stripe's.
        Logger.error("Webhook processing failed: #{inspect(reason)} for event #{event_id}")
        conn |> put_status(500) |> json(%{error: "Failed to process event"})
    end
  end
end
