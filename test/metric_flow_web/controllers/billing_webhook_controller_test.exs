defmodule MetricFlowWeb.BillingWebhookControllerTest do
  use MetricFlowTest.ConnCase

  import ExUnit.CaptureLog

  @webhook_secret "whsec_test_secret"

  setup do
    Application.put_env(:metric_flow, :stripe_webhook_secret, @webhook_secret)

    on_exit(fn ->
      Application.delete_env(:metric_flow, :stripe_webhook_secret)
    end)

    :ok
  end

  defp sign_payload(payload, timestamp \\ nil) do
    timestamp = timestamp || System.system_time(:second) |> to_string()
    signed = "#{timestamp}.#{payload}"
    signature = :crypto.mac(:hmac, :sha256, @webhook_secret, signed) |> Base.encode16(case: :lower)
    "t=#{timestamp},v1=#{signature}"
  end

  defp subscription_event(type, overrides \\ %{}) do
    base = %{
      "id" => "sub_test_#{System.unique_integer([:positive])}",
      "customer" => "cus_test",
      "status" => "active",
      "items" => %{"data" => [%{"price" => %{"id" => "price_test"}}]},
      "current_period_start" => 1_700_000_000,
      "current_period_end" => 1_702_592_000
    }

    %{
      "id" => "evt_test_#{System.unique_integer([:positive])}",
      "type" => type,
      "data" => %{"object" => Map.merge(base, overrides)}
    }
  end

  defp post_webhook(conn, payload, opts \\ []) do
    json_payload = if is_binary(payload), do: payload, else: Jason.encode!(payload)
    include_signature = Keyword.get(opts, :signature, true)

    conn = conn
      |> put_req_header("content-type", "application/json")
      |> Plug.Conn.assign(:raw_body, json_payload)

    conn = if include_signature do
      put_req_header(conn, "stripe-signature", sign_payload(json_payload))
    else
      conn
    end

    post(conn, "/billing/webhooks", json_payload)
  end

  describe "handle/2" do
    test "returns 200 for valid subscription.created event", %{conn: conn} do
      event = subscription_event("customer.subscription.created")

      capture_log(fn ->
        conn = post_webhook(conn, event)
        assert json_response(conn, 200)["received"] == true
      end)
    end

    test "returns 200 for valid subscription.updated event", %{conn: conn} do
      event = subscription_event("customer.subscription.updated")

      capture_log(fn ->
        conn = post_webhook(conn, event)
        assert json_response(conn, 200)["received"] == true
      end)
    end

    test "returns 200 for valid subscription.deleted event", %{conn: conn} do
      event = subscription_event("customer.subscription.deleted", %{
        "status" => "canceled",
        "canceled_at" => 1_700_100_000
      })

      capture_log(fn ->
        conn = post_webhook(conn, event)
        assert json_response(conn, 200)["received"] == true
      end)
    end

    test "returns 200 for valid invoice.payment_failed event", %{conn: conn} do
      event = %{
        "id" => "evt_pf_#{System.unique_integer([:positive])}",
        "type" => "invoice.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "in_test",
            "customer" => "cus_test",
            "subscription" => "sub_test",
            "status" => "open"
          }
        }
      }

      capture_log(fn ->
        conn = post_webhook(conn, event)
        assert json_response(conn, 200)["received"] == true
      end)
    end

    test "returns 200 for valid invoice.payment_succeeded event", %{conn: conn} do
      event = %{
        "id" => "evt_ps_#{System.unique_integer([:positive])}",
        "type" => "invoice.payment_succeeded",
        "data" => %{
          "object" => %{
            "id" => "in_success",
            "customer" => "cus_test",
            "subscription" => "sub_test",
            "status" => "paid"
          }
        }
      }

      capture_log(fn ->
        conn = post_webhook(conn, event)
        assert json_response(conn, 200)["received"] == true
      end)
    end

    test "returns 200 for valid account.updated event (Connect onboarding)", %{conn: conn} do
      event = %{
        "id" => "evt_acct_#{System.unique_integer([:positive])}",
        "type" => "account.updated",
        "data" => %{
          "object" => %{
            "id" => "acct_test",
            "charges_enabled" => true,
            "capabilities" => %{"card_payments" => "active"}
          }
        }
      }

      capture_log(fn ->
        conn = post_webhook(conn, event)
        assert json_response(conn, 200)["received"] == true
      end)
    end

    test "returns 200 for unrecognized event types without crashing", %{conn: conn} do
      event = %{
        "id" => "evt_unk_#{System.unique_integer([:positive])}",
        "type" => "unknown.event.type",
        "data" => %{"object" => %{}}
      }

      conn = post_webhook(conn, event)
      response = json_response(conn, 200)
      assert response["received"] == true
      assert response["ignored"] == true
    end

    test "returns 400 when Stripe-Signature header is missing", %{conn: conn} do
      event = subscription_event("customer.subscription.created")

      conn = post_webhook(conn, event, signature: false)
      assert json_response(conn, 400)["error"] =~ "Missing"
    end

    test "returns 400 when signature verification fails", %{conn: conn} do
      payload = Jason.encode!(subscription_event("customer.subscription.created"))

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", "t=123,v1=invalidsignature")
        |> Plug.Conn.assign(:raw_body, payload)
        |> post("/billing/webhooks", payload)

      assert json_response(conn, 400)["error"] =~ "Invalid signature"
    end

    test "returns 400 for malformed JSON payload", %{conn: conn} do
      bad_payload = "not valid json at all"
      signature = sign_payload(bad_payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", signature)
        |> Plug.Conn.assign(:raw_body, bad_payload)
        |> post("/billing/webhooks", bad_payload)

      assert json_response(conn, 400)["error"] =~ "Invalid JSON"
    end

    test "handles duplicate event delivery idempotently (same event ID processed twice returns 200 both times)", %{conn: conn} do
      event = subscription_event("customer.subscription.created")

      capture_log(fn ->
        conn1 = post_webhook(build_conn(), event)
        assert json_response(conn1, 200)["received"] == true

        conn2 = post_webhook(build_conn(), event)
        assert json_response(conn2, 200)["received"] == true
      end)
    end
  end
end
