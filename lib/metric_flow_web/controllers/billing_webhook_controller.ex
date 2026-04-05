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
    webhook_secret = Application.get_env(:metric_flow, :stripe_webhook_secret, "")
    StripeClient.verify_webhook_signature(raw_body, signature, webhook_secret)
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

      {:error, reason} ->
        Logger.error("Webhook processing failed: #{inspect(reason)} for event #{event_id}")
        conn |> put_status(200) |> json(%{received: true})
    end
  end
end
