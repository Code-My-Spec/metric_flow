defmodule MetricFlow.Billing.StripeClientTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Billing.StripeClient

  @test_secret "whsec_test_secret_key"

  defp build_signature(raw_body, secret) do
    timestamp = System.system_time(:second) |> to_string()

    signed_payload = "#{timestamp}.#{raw_body}"

    hex =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    {"t=#{timestamp},v1=#{hex}", timestamp}
  end

  describe "verify_webhook_signature/3" do
    test "returns event for valid signature" do
      raw_body = Jason.encode!(%{"type" => "checkout.session.completed", "id" => "evt_123"})
      {signature, _ts} = build_signature(raw_body, @test_secret)

      assert {:ok, event} = StripeClient.verify_webhook_signature(raw_body, signature, @test_secret)
      assert event["type"] == "checkout.session.completed"
      assert event["id"] == "evt_123"
    end

    test "returns error for missing signature" do
      raw_body = Jason.encode!(%{"type" => "test"})

      assert {:error, :missing_signature} =
               StripeClient.verify_webhook_signature(raw_body, nil, @test_secret)

      assert {:error, :missing_signature} =
               StripeClient.verify_webhook_signature(raw_body, "", @test_secret)
    end

    test "returns error for mismatched signature" do
      raw_body = Jason.encode!(%{"type" => "test"})
      {signature, _ts} = build_signature(raw_body, "wrong_secret")

      assert {:error, :signature_mismatch} =
               StripeClient.verify_webhook_signature(raw_body, signature, @test_secret)
    end

    test "returns error for invalid JSON body" do
      raw_body = "not valid json {{"
      {signature, _ts} = build_signature(raw_body, @test_secret)

      assert {:error, :invalid_json} =
               StripeClient.verify_webhook_signature(raw_body, signature, @test_secret)
    end
  end

  describe "create_checkout_session/3" do
    @tag :integration
    @tag :skip
    test "creates session and returns URL" do
      plan = %{stripe_price_id: "price_test_123"}
      assert {:ok, session} = StripeClient.create_checkout_session(plan, "https://example.com/return")
      assert is_binary(session["url"])
    end
  end

  describe "create_express_account/0" do
    @tag :integration
    @tag :skip
    test "creates account and returns account map" do
      assert {:ok, account} = StripeClient.create_express_account()
      assert is_binary(account["id"])
    end
  end

  describe "create_account_link/1" do
    @tag :integration
    @tag :skip
    test "creates link and returns URL" do
      assert {:ok, link} = StripeClient.create_account_link("acct_test")
      assert is_binary(link["url"])
    end
  end

  describe "create_product/2" do
    @tag :integration
    @tag :skip
    test "creates product and returns product map" do
      assert {:ok, product} = StripeClient.create_product("Test Product")
      assert is_binary(product["id"])
    end
  end

  describe "create_price/3" do
    @tag :integration
    @tag :skip
    test "creates price and returns price map" do
      assert {:ok, price} = StripeClient.create_price("prod_test", 1999)
      assert is_binary(price["id"])
    end
  end

  describe "deactivate_price/2" do
    @tag :integration
    @tag :skip
    test "deactivates price successfully" do
      assert {:ok, price} = StripeClient.deactivate_price("price_test")
      assert price["active"] == false
    end
  end

  describe "cancel_subscription/2" do
    @tag :integration
    @tag :skip
    test "cancels subscription at period end" do
      assert {:ok, sub} = StripeClient.cancel_subscription("sub_test")
      assert sub["cancel_at_period_end"] == true
    end
  end
end
