defmodule MetricFlow.DataSync.DataProviders.QuickBooks do
  @moduledoc """
  QuickBooks Online data provider.

  Fetches daily credit and debit totals for the user's selected income account
  using the TransactionList report filtered by account ID. Produces two metric
  series — `QUICKBOOKS_ACCOUNT_DAILY_CREDITS` and `QUICKBOOKS_ACCOUNT_DAILY_DEBITS`
  — each recorded per day for correlation analysis.

  Positive transaction amounts are credits (money in), negative are debits (money out).
  Days with no transactions are backfilled as zero-value records to preserve
  continuity for correlation calculations.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  require Logger

  alias MetricFlow.Integrations.Integration

  @default_base_url "https://sandbox-quickbooks.api.intuit.com/v3/company"
  @default_date_range_days 548

  defp base_url, do: Application.get_env(:metric_flow, :quickbooks_api_url, @default_base_url)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @impl true
  @spec provider() :: :quickbooks
  def provider, do: :quickbooks

  @impl true
  @spec required_scopes() :: list(String.t())
  def required_scopes, do: ["com.intuit.quickbooks.accounting"]

  @impl true
  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_metrics(%Integration{} = integration, opts \\ []) do
    with :ok <- check_not_expired(integration),
         {:ok, realm_id} <- resolve_realm_id(integration, opts),
         {:ok, account_id} <- resolve_account_id(integration, opts),
         {:ok, {start_date, end_date}} <- resolve_date_range(opts) do
      http_plug = Keyword.get(opts, :http_plug)

      case fetch_transaction_list(integration, realm_id, account_id, start_date, end_date, http_plug) do
        {:ok, daily_totals} ->
          metrics = build_daily_metrics(daily_totals, account_id, start_date, end_date)
          {:ok, metrics}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — validation
  # ---------------------------------------------------------------------------

  defp check_not_expired(%Integration{} = integration) do
    if Integration.expired?(integration), do: {:error, :unauthorized}, else: :ok
  end

  defp resolve_realm_id(%Integration{provider_metadata: meta}, opts) do
    realm_id = Keyword.get(opts, :realm_id) || get_in(meta, ["realm_id"])
    if realm_id, do: {:ok, realm_id}, else: {:error, :missing_realm_id}
  end

  defp resolve_account_id(%Integration{provider_metadata: meta}, opts) do
    account_id = Keyword.get(opts, :account_id) || get_in(meta, ["income_account_id"])
    if account_id, do: {:ok, account_id}, else: {:error, :missing_account_id}
  end

  defp resolve_date_range(opts) do
    case Keyword.get(opts, :date_range) do
      nil ->
        today = Date.utc_today()
        {:ok, {Date.add(today, -@default_date_range_days), today}}

      {start_date, end_date} ->
        if Date.compare(start_date, end_date) == :gt do
          {:error, :invalid_date_range}
        else
          {:ok, {start_date, end_date}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private — HTTP: TransactionList report filtered by account
  # ---------------------------------------------------------------------------

  defp fetch_transaction_list(integration, realm_id, account_id, start_date, end_date, http_plug) do
    url = "#{base_url()}/#{realm_id}/reports/TransactionList"

    Logger.info(
      "QuickBooks fetching TransactionList account=#{account_id} realm=#{realm_id} dates=#{start_date}..#{end_date}"
    )

    req_opts =
      [
        url: url,
        params: [
          start_date: Date.to_iso8601(start_date),
          end_date: Date.to_iso8601(end_date),
          account: account_id
        ],
        headers: [
          {"Authorization", "Bearer #{integration.access_token}"},
          {"Accept", "application/json"}
        ]
      ]
      |> maybe_add_plug(http_plug)

    try do
      response = Req.get!(req_opts)
      handle_response(response)
    rescue
      e in Req.TransportError ->
        {:error, {:network_error, e.reason}}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  # ---------------------------------------------------------------------------
  # Private — response handling
  # ---------------------------------------------------------------------------

  defp handle_response(%Req.Response{status: 200, body: body}) do
    parsed = if is_binary(body), do: Jason.decode!(body), else: body
    {:ok, extract_daily_totals(parsed)}
  end

  defp handle_response(%Req.Response{status: 401, body: body}) do
    Logger.error("QuickBooks API 401: #{inspect(body)}")
    {:error, :unauthorized}
  end

  defp handle_response(%Req.Response{status: 403, body: body}) do
    Logger.error("QuickBooks API 403: #{inspect(body)}")
    {:error, :insufficient_permissions}
  end

  defp handle_response(%Req.Response{status: 404}), do: {:error, :company_not_found}

  defp handle_response(%Req.Response{status: 400, body: body}) do
    Logger.error("QuickBooks API 400: #{inspect(body)}")
    {:error, :bad_request}
  end

  defp handle_response(%Req.Response{status: status, body: body}) do
    Logger.error("QuickBooks API unexpected #{status}: #{inspect(body)}")
    {:error, {:unexpected_status, status, body}}
  end

  # ---------------------------------------------------------------------------
  # Private — TransactionList report parsing
  #
  # The TransactionList report returns rows grouped in Sections. Each Section
  # has a Header, nested Data rows in Rows.Row[], and a Summary.
  # Data rows contain ColData arrays matching the Columns definition.
  #
  # We request tx_date and subt_nat_home_amount columns. Positive amounts are
  # credits (money in), negative amounts are debits (money out).
  # ---------------------------------------------------------------------------

  defp extract_daily_totals(report) do
    columns = extract_column_indices(report)
    rows = get_in(report, ["Rows", "Row"]) || []

    rows
    |> collect_data_rows([])
    |> Enum.reduce(%{}, fn col_data, acc ->
      date_str = get_col_value(col_data, columns.date)
      amount = parse_amount(get_col_value(col_data, columns.amount))

      case parse_date(date_str) do
        nil ->
          acc

        date ->
          existing = Map.get(acc, date, %{credits: 0.0, debits: 0.0})
          Map.put(acc, date, apply_amount(existing, amount))
      end
    end)
  end

  defp apply_amount(existing, amount) when amount >= 0,
    do: %{existing | credits: existing.credits + amount}

  defp apply_amount(existing, amount),
    do: %{existing | debits: existing.debits + abs(amount)}

  # Recursively walk nested report rows to find Data rows.
  # Sections contain Rows.Row[] with the actual data.
  defp collect_data_rows([], acc), do: acc

  defp collect_data_rows([row | rest], acc) do
    acc =
      case row do
        %{"type" => "Data", "ColData" => col_data} ->
          [col_data | acc]

        %{"Rows" => %{"Row" => sub_rows}} ->
          collect_data_rows(sub_rows, acc)

        _ ->
          acc
      end

    collect_data_rows(rest, acc)
  end

  defp extract_column_indices(report) do
    get_in(report, ["Columns", "Column"])
    |> Kernel.||([])
    |> Enum.with_index()
    |> Enum.reduce(%{date: 0, amount: 1}, fn {col, idx}, acc ->
      col_type = col["ColType"] || ""

      cond do
        col_type == "tx_date" -> %{acc | date: idx}
        col_type in ~w(subt_nat_home_amount subt_nat_amount net_amount) -> %{acc | amount: idx}
        true -> acc
      end
    end)
  end

  defp get_col_value(col_data, idx) when is_list(col_data) do
    case Enum.at(col_data, idx) do
      %{"value" => value} -> value
      _ -> nil
    end
  end

  defp get_col_value(_, _), do: nil

  defp parse_amount(nil), do: 0.0
  defp parse_amount(""), do: 0.0
  defp parse_amount(value) when is_float(value), do: value
  defp parse_amount(value) when is_integer(value), do: value * 1.0

  defp parse_amount(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_amount(_), do: 0.0

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_date(_), do: nil

  # ---------------------------------------------------------------------------
  # Private — metric construction
  #
  # Builds daily credit and debit metric records, filling in zero-value records
  # for days with no transactions to preserve continuity for correlations.
  # ---------------------------------------------------------------------------

  defp build_daily_metrics(daily_totals, account_id, start_date, end_date) do
    all_dates = Date.range(start_date, end_date)

    Enum.flat_map(all_dates, fn date ->
      totals = Map.get(daily_totals, date, %{credits: 0.0, debits: 0.0})
      recorded_at = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

      metadata = %{account_id: account_id}

      [
        %{
          metric_type: "financial",
          metric_name: "QUICKBOOKS_ACCOUNT_DAILY_CREDITS",
          normalized_metric_name: "revenue",
          value: totals.credits,
          recorded_at: recorded_at,
          metadata: metadata,
          provider: :quickbooks
        },
        %{
          metric_type: "financial",
          metric_name: "QUICKBOOKS_ACCOUNT_DAILY_DEBITS",
          normalized_metric_name: "expenses",
          value: totals.debits,
          recorded_at: recorded_at,
          metadata: metadata,
          provider: :quickbooks
        }
      ]
    end)
  end
end
