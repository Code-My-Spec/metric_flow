defmodule MetricFlow.Billing.StripeClient do
  @moduledoc """
  Stripe API integration layer.

  Handles webhook signature verification, checkout session creation,
  and subscription management. Accepts an `:http_plug` option for
  dependency injection during tests.
  """

  @doc """
  Verify a Stripe webhook signature against the raw request body.

  Returns {:ok, event} if valid, {:error, reason} if invalid.
  """
  @spec verify_webhook_signature(binary(), binary(), binary()) ::
          {:ok, map()} | {:error, term()}
  def verify_webhook_signature(raw_body, signature, webhook_secret) do
    case compute_and_verify(raw_body, signature, webhook_secret) do
      :ok ->
        case Jason.decode(raw_body) do
          {:ok, event} -> {:ok, event}
          {:error, _} -> {:error, :invalid_json}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compute_and_verify(_raw_body, nil, _secret), do: {:error, :missing_signature}
  defp compute_and_verify(_raw_body, "", _secret), do: {:error, :missing_signature}

  defp compute_and_verify(raw_body, signature, secret) do
    with {:ok, timestamp, signatures} <- parse_signature(signature),
         expected <- compute_expected(timestamp, raw_body, secret),
         true <- Enum.any?(signatures, &Plug.Crypto.secure_compare(&1, expected)) do
      :ok
    else
      false -> {:error, :signature_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_signature(signature) do
    parts =
      signature
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reduce(%{}, fn part, acc ->
        case String.split(part, "=", parts: 2) do
          [key, value] -> Map.update(acc, key, [value], &[value | &1])
          _ -> acc
        end
      end)

    with [timestamp | _] <- Map.get(parts, "t", []),
         signatures when signatures != [] <- Map.get(parts, "v1", []) do
      {:ok, timestamp, signatures}
    else
      _ -> {:error, :invalid_signature_format}
    end
  end

  @stripe_api_base "https://api.stripe.com/v1"

  @doc """
  Create a Stripe Product for an agency plan.

  Returns {:ok, product_map} or {:error, reason}.
  """
  @spec create_product(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_product(name, opts \\ []) do
    body = URI.encode_query(%{"name" => name, "type" => "service"})
    post("#{@stripe_api_base}/products", body, opts)
  end

  @doc """
  Create a Stripe Price for a product.

  Returns {:ok, price_map} or {:error, reason}.
  """
  @spec create_price(String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_price(product_id, amount_cents, opts \\ []) do
    currency = Keyword.get(opts, :currency, "usd")
    interval = Keyword.get(opts, :interval, "month")

    body =
      URI.encode_query(%{
        "product" => product_id,
        "unit_amount" => to_string(amount_cents),
        "currency" => currency,
        "recurring[interval]" => interval
      })

    post("#{@stripe_api_base}/prices", body, opts)
  end

  @doc """
  Deactivate a Stripe Price by setting active to false.

  Returns {:ok, price_map} or {:error, reason}.
  """
  @spec deactivate_price(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def deactivate_price(price_id, opts \\ []) do
    body = URI.encode_query(%{"active" => "false"})
    post("#{@stripe_api_base}/prices/#{price_id}", body, opts)
  end

  @doc """
  Create a Stripe Checkout session for a plan.
  """
  @spec create_checkout_session(map(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_checkout_session(plan, return_url, opts \\ []) do
    body =
      URI.encode_query(%{
        "mode" => "subscription",
        "line_items[0][price]" => plan.stripe_price_id || "price_placeholder",
        "line_items[0][quantity]" => "1",
        "success_url" => return_url <> "?success=true&session_id={CHECKOUT_SESSION_ID}",
        "cancel_url" => return_url <> "?cancelled=true"
      })

    post("#{@stripe_api_base}/checkout/sessions", body, opts)
  end

  @doc """
  Cancel a Stripe subscription at period end.
  """
  @spec cancel_subscription(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel_subscription(subscription_id, opts \\ []) do
    body = URI.encode_query(%{"cancel_at_period_end" => "true"})
    post("#{@stripe_api_base}/subscriptions/#{subscription_id}", body, opts)
  end

  @doc """
  Create a Stripe Connect Express account.
  """
  @spec create_express_account(keyword()) :: {:ok, map()} | {:error, term()}
  def create_express_account(opts \\ []) do
    body = URI.encode_query(%{"type" => "express"})
    post("#{@stripe_api_base}/accounts", body, opts)
  end

  @doc """
  Create an account link for Stripe Connect onboarding.

  Returns the onboarding URL the agency admin should be redirected to.
  """
  @spec create_account_link(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_account_link(stripe_account_id, opts \\ []) do
    return_url = MetricFlowWeb.Endpoint.url() <> "/agency/stripe-connect"

    body =
      URI.encode_query(%{
        "account" => stripe_account_id,
        "refresh_url" => return_url,
        "return_url" => return_url,
        "type" => "account_onboarding"
      })

    post("#{@stripe_api_base}/account_links", body, opts)
  end

  defp post(url, body, opts) do
    stripe_account = Keyword.get(opts, :stripe_account)
    headers = api_headers(stripe_account)
    req_opts = [body: body, headers: headers] ++ req_http_options(opts)

    case Req.post(url, req_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{body: body}} ->
        {:error, body["error"]["message"] || "Stripe API error"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp req_http_options(opts) do
    case Keyword.get(opts, :plug) do
      nil -> []
      plug -> [plug: plug]
    end
  end

  defp api_headers(nil) do
    secret_key = Application.get_env(:metric_flow, :stripe_secret_key, "")
    [{"authorization", "Bearer #{secret_key}"}, {"content-type", "application/x-www-form-urlencoded"}]
  end

  defp api_headers(stripe_account_id) do
    api_headers(nil) ++ [{"stripe-account", stripe_account_id}]
  end

  defp compute_expected(timestamp, raw_body, secret) do
    signed_payload = "#{timestamp}.#{raw_body}"

    :crypto.mac(:hmac, :sha256, secret, signed_payload)
    |> Base.encode16(case: :lower)
  end
end
