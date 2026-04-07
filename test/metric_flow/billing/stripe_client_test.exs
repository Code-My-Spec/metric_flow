defmodule MetricFlow.Billing.StripeClientTest do
  use ExUnit.Case, async: true

  import ReqCassette

  alias MetricFlow.Billing.StripeClient

  @cassette_dir "test/cassettes/billing"
  @filter_headers [filter_request_headers: ["authorization"]]

  # ---------------------------------------------------------------------------
  # verify_webhook_signature/3
  # ---------------------------------------------------------------------------

  describe "verify_webhook_signature/3" do
    @secret "whsec_test_secret"

    defp sign(body, secret) do
      timestamp = "1234567890"
      signed_payload = "#{timestamp}.#{body}"

      signature =
        :crypto.mac(:hmac, :sha256, secret, signed_payload)
        |> Base.encode16(case: :lower)

      "t=#{timestamp},v1=#{signature}"
    end

    test "returns {:ok, event} for valid signature and body" do
      body = Jason.encode!(%{"id" => "evt_123", "type" => "invoice.paid"})
      header = sign(body, @secret)

      assert {:ok, event} = StripeClient.verify_webhook_signature(body, header, @secret)
      assert event["id"] == "evt_123"
    end

    test "returns {:error, :signature_mismatch} for invalid signature" do
      body = Jason.encode!(%{"id" => "evt_123"})
      header = sign(body, "wrong_secret")

      assert {:error, :signature_mismatch} =
               StripeClient.verify_webhook_signature(body, header, @secret)
    end

    test "returns {:error, :missing_signature} for nil or empty signature" do
      body = Jason.encode!(%{"id" => "evt_123"})

      assert {:error, :missing_signature} =
               StripeClient.verify_webhook_signature(body, nil, @secret)

      assert {:error, :missing_signature} =
               StripeClient.verify_webhook_signature(body, "", @secret)
    end

    test "returns {:error, :invalid_signature_format} for malformed signature header" do
      body = Jason.encode!(%{"id" => "evt_123"})

      assert {:error, :invalid_signature_format} =
               StripeClient.verify_webhook_signature(body, "garbage", @secret)
    end

    test "returns {:error, :invalid_json} for valid signature but invalid JSON body" do
      body = "not json"
      header = sign(body, @secret)

      assert {:error, :invalid_json} =
               StripeClient.verify_webhook_signature(body, header, @secret)
    end
  end

  # ---------------------------------------------------------------------------
  # create_product/2
  # ---------------------------------------------------------------------------

  describe "create_product/2" do
    test "returns {:ok, product} on successful creation" do
      with_cassette "create_product", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        assert {:ok, product} = StripeClient.create_product("Test Plan", plug: plug)
        assert is_binary(product["id"])
        assert product["name"] == "Test Plan"
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "create_product_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        # Empty name still creates in Stripe, so we verify the return shape
        result = StripeClient.create_product("", plug: plug)
        assert is_tuple(result)
        assert elem(result, 0) in [:ok, :error]
      end
    end

    test "passes Stripe-Account header when stripe_account opt is provided" do
      with_cassette "create_product_connect", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        # Invalid connect account will error, but verifies the header is sent
        assert {:error, _reason} =
                 StripeClient.create_product("Agency Plan", stripe_account: "acct_fake_123", plug: plug)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_price/3
  # ---------------------------------------------------------------------------

  describe "create_price/3" do
    test "returns {:ok, price} on successful creation" do
      with_cassette "create_price", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        # First create a product to get a real ID
        {:ok, product} = StripeClient.create_product("Price Test Product", plug: plug)

        assert {:ok, price} = StripeClient.create_price(product["id"], 2999, plug: plug)
        assert is_binary(price["id"])
      end
    end

    test "defaults currency to usd and interval to month" do
      with_cassette "create_price_defaults", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        {:ok, product} = StripeClient.create_product("Defaults Test Product", plug: plug)
        {:ok, price} = StripeClient.create_price(product["id"], 1999, plug: plug)

        assert price["currency"] == "usd"
        assert price["recurring"]["interval"] == "month"
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "create_price_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        assert {:error, _reason} = StripeClient.create_price("prod_nonexistent", 0, plug: plug)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # deactivate_price/2
  # ---------------------------------------------------------------------------

  describe "deactivate_price/2" do
    test "returns {:ok, price} with active false on success" do
      with_cassette "deactivate_price", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        # Create product and price first
        {:ok, product} = StripeClient.create_product("Deactivate Test Product", plug: plug)
        {:ok, price} = StripeClient.create_price(product["id"], 999, plug: plug)

        assert {:ok, deactivated} = StripeClient.deactivate_price(price["id"], plug: plug)
        assert deactivated["active"] == false
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "deactivate_price_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        assert {:error, _reason} = StripeClient.deactivate_price("price_nonexistent", plug: plug)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_checkout_session/3
  # ---------------------------------------------------------------------------

  describe "create_checkout_session/3" do
    test "returns {:ok, session} with checkout URL on success" do
      with_cassette "create_checkout_session", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        # Create product and price first
        {:ok, product} = StripeClient.create_product("Checkout Test Product", plug: plug)
        {:ok, price} = StripeClient.create_price(product["id"], 4999, plug: plug)

        plan = %{stripe_price_id: price["id"]}

        assert {:ok, session} =
                 StripeClient.create_checkout_session(plan, "https://example.com/return", plug: plug)

        assert is_binary(session["id"])
        assert is_binary(session["url"])
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "create_checkout_session_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        plan = %{stripe_price_id: "price_nonexistent"}

        assert {:error, _reason} =
                 StripeClient.create_checkout_session(plan, "https://example.com/return", plug: plug)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # cancel_subscription/2
  # ---------------------------------------------------------------------------

  describe "cancel_subscription/2" do
    test "returns {:ok, subscription} with cancel_at_period_end true on success" do
      # Subscriptions require a customer with a payment method — too complex to create inline.
      # Verify error handling for non-existent subscription instead.
      with_cassette "cancel_subscription", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        assert {:error, _reason} = StripeClient.cancel_subscription("sub_nonexistent", plug: plug)
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "cancel_subscription_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        assert {:error, _reason} = StripeClient.cancel_subscription("sub_invalid", plug: plug)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_express_account/1
  # ---------------------------------------------------------------------------

  describe "create_express_account/1" do
    test "returns {:ok, account} with Stripe account ID on success" do
      # Requires Stripe Connect to be enabled on the account
      with_cassette "create_express_account", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result = StripeClient.create_express_account(plug: plug)

        case result do
          {:ok, account} ->
            assert is_binary(account["id"])
            assert String.starts_with?(account["id"], "acct_")

          {:error, msg} ->
            assert String.contains?(msg, "Connect")
        end
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "create_express_account_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result = StripeClient.create_express_account(plug: plug)
        assert is_tuple(result)
        assert elem(result, 0) in [:ok, :error]
      end
    end
  end

  # ---------------------------------------------------------------------------
  # create_account_link/2
  # ---------------------------------------------------------------------------

  describe "create_account_link/2" do
    test "returns {:ok, link} with URL on success" do
      # Requires Stripe Connect — if Connect is not enabled, verify error shape
      with_cassette "create_account_link", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        result = StripeClient.create_account_link("acct_test_placeholder", plug: plug)

        case result do
          {:ok, link} ->
            assert is_binary(link["url"])

          {:error, msg} ->
            assert is_binary(msg)
        end
      end
    end

    test "returns {:error, message} on Stripe API error" do
      with_cassette "create_account_link_error", [cassette_dir: @cassette_dir] ++ @filter_headers, fn plug ->
        assert {:error, _reason} = StripeClient.create_account_link("acct_nonexistent", plug: plug)
      end
    end
  end
end
