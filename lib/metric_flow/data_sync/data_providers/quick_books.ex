defmodule MetricFlow.DataSync.DataProviders.QuickBooks do
  @moduledoc """
  QuickBooks Online Accounting API data provider.

  Fetches financial metrics including revenue, expenses, net_income, gross_profit,
  accounts_receivable, accounts_payable, and cash_on_hand from the ProfitAndLoss and
  BalanceSheet reports. Transforms API responses to the unified metric format with
  provider set to :quickbooks.
  """

  @behaviour MetricFlow.DataSync.DataProviders.Behaviour

  alias MetricFlow.Integrations.Integration

  @base_url "https://quickbooks.api.intuit.com/v3/company"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Fetches QuickBooks financial metrics for an integration using OAuth tokens.

  Fetches both ProfitAndLoss and BalanceSheet reports, extracting revenue,
  expenses, net_income, gross_profit, accounts_receivable, accounts_payable,
  and cash_on_hand. Supports configurable date range, realm_id (company), and
  accounting method.

  Returns `{:ok, list(map())}` on success or `{:error, reason}` on failure.
  """
  @spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def fetch_metrics(%Integration{} = integration, opts \\ []) do
    with :ok <- check_not_expired(integration),
         {:ok, realm_id} <- resolve_realm_id(integration, opts),
         {:ok, date_range} <- resolve_date_range(opts) do
      accounting_method = Keyword.get(opts, :accounting_method, "Accrual")
      http_plug = Keyword.get(opts, :http_plug)
      {start_date, end_date} = date_range

      with {:ok, pl_metrics} <-
             fetch_report(integration, realm_id, "ProfitAndLoss", start_date, end_date,
               accounting_method: accounting_method,
               http_plug: http_plug,
               report_type: :profit_and_loss
             ),
           {:ok, bs_metrics} <-
             fetch_report(integration, realm_id, "BalanceSheet", start_date, end_date,
               accounting_method: accounting_method,
               http_plug: http_plug,
               report_type: :balance_sheet
             ) do
        recorded_at = date_to_datetime(end_date)
        pl = tag_metrics(pl_metrics, realm_id, accounting_method, :profit_and_loss, recorded_at)
        bs = tag_metrics(bs_metrics, realm_id, accounting_method, :balance_sheet, recorded_at)
        {:ok, pl ++ bs}
      end
    end
  end

  @doc """
  Returns the provider atom identifier for QuickBooks.
  """
  @spec provider() :: :quickbooks
  def provider, do: :quickbooks

  @doc """
  Returns the OAuth scopes required to fetch QuickBooks financial reports.
  """
  @spec required_scopes() :: list(String.t())
  def required_scopes, do: ["com.intuit.quickbooks.accounting"]

  # ---------------------------------------------------------------------------
  # Private helpers — validation / setup
  # ---------------------------------------------------------------------------

  defp check_not_expired(%Integration{} = integration) do
    if Integration.expired?(integration), do: {:error, :unauthorized}, else: :ok
  end

  defp resolve_realm_id(%Integration{provider_metadata: meta}, opts) do
    realm_id =
      Keyword.get(opts, :realm_id) || get_in(meta, ["realm_id"])

    if realm_id, do: {:ok, realm_id}, else: {:error, :missing_realm_id}
  end

  defp resolve_date_range(opts) do
    case Keyword.get(opts, :date_range) do
      nil ->
        today = Date.utc_today()
        {:ok, {Date.add(today, -30), today}}

      {start_date, end_date} ->
        validate_date_range(start_date, end_date)
    end
  end

  defp validate_date_range(start_date, end_date) do
    if Date.compare(start_date, end_date) == :gt do
      {:error, :invalid_date_range}
    else
      {:ok, {start_date, end_date}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — HTTP
  # ---------------------------------------------------------------------------

  defp fetch_report(integration, realm_id, report_type, start_date, end_date, opts) do
    url = "#{@base_url}/#{realm_id}/reports/#{report_type}"
    accounting_method = Keyword.get(opts, :accounting_method, "Accrual")
    http_plug = Keyword.get(opts, :http_plug)

    req_opts =
      [
        url: url,
        params: [
          start_date: Date.to_iso8601(start_date),
          end_date: Date.to_iso8601(end_date),
          accounting_method: accounting_method
        ],
        headers: [
          {"Authorization", "Bearer #{integration.access_token}"},
          {"Accept", "application/json"}
        ]
      ]
      |> maybe_add_plug(http_plug)

    try do
      response = Req.get!(req_opts)
      handle_response(response, Keyword.get(opts, :report_type))
    rescue
      e in Req.TransportError ->
        {:error, {:network_error, e.reason}}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  defp handle_response(%Req.Response{status: 200, body: body}, report_type) do
    case parse_body(body) do
      {:ok, parsed} -> extract_metrics(parsed, report_type)
      {:error, _} = err -> err
    end
  end

  defp handle_response(%Req.Response{status: 401}, _report_type), do: {:error, :unauthorized}
  defp handle_response(%Req.Response{status: 403}, _report_type), do: {:error, :insufficient_permissions}
  defp handle_response(%Req.Response{status: 404}, _report_type), do: {:error, :company_not_found}

  defp handle_response(%Req.Response{status: 400, body: body}, _report_type) do
    details =
      case parse_body(body) do
        {:ok, parsed} -> parsed
        _ -> body
      end

    {:error, details}
  end

  defp handle_response(%Req.Response{status: status, body: body}, _report_type) do
    {:error, {:unexpected_status, status, body}}
  end

  defp parse_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp parse_body(body) when is_map(body), do: {:ok, body}

  # ---------------------------------------------------------------------------
  # Private helpers — report extraction
  # ---------------------------------------------------------------------------

  defp extract_metrics(report, :profit_and_loss) do
    rows = get_in(report, ["Rows", "Row"]) || []
    revenue = extract_section_summary(rows, "Income")
    cogs = extract_section_summary(rows, "COGS")
    expenses = extract_section_summary(rows, "Expenses")
    net_income = extract_net_income(rows, revenue, expenses)

    metrics = [
      %{metric_type: "financial", metric_name: "revenue", value: revenue},
      %{metric_type: "financial", metric_name: "expenses", value: expenses},
      %{metric_type: "financial", metric_name: "net_income", value: net_income},
      %{metric_type: "financial", metric_name: "gross_profit", value: revenue - cogs}
    ]

    {:ok, metrics}
  end

  defp extract_metrics(report, :balance_sheet) do
    rows = get_in(report, ["Rows", "Row"]) || []

    metrics = [
      %{
        metric_type: "financial",
        metric_name: "cash_on_hand",
        value: extract_nested_group_summary(rows, "TotalAssets", "Bank")
      },
      %{
        metric_type: "financial",
        metric_name: "accounts_receivable",
        value: extract_nested_group_summary(rows, "TotalAssets", "AR")
      },
      %{
        metric_type: "financial",
        metric_name: "accounts_payable",
        value: extract_nested_group_summary(rows, "TotalLiabilities", "AP")
      }
    ]

    {:ok, metrics}
  end

  # Find a top-level section by group and return its Summary value.
  defp extract_section_summary(rows, group) do
    case Enum.find(rows, fn row -> row["group"] == group end) do
      nil -> 0.0
      section -> parse_col_data_value(get_in(section, ["Summary", "ColData"]))
    end
  end

  # Extract net income from the NetIncome section summary, or fall back to revenue - expenses.
  defp extract_net_income(rows, revenue, expenses) do
    case Enum.find(rows, fn row -> row["group"] == "NetIncome" end) do
      nil -> revenue - expenses
      section -> parse_col_data_value(get_in(section, ["Summary", "ColData"]))
    end
  end

  # Recursively search through sections nested under `top_group` to find `target_group`.
  defp extract_nested_group_summary(rows, top_group, target_group) do
    case Enum.find(rows, fn row -> row["group"] == top_group end) do
      nil ->
        0.0

      top_section ->
        nested_rows = get_in(top_section, ["Rows", "Row"]) || []
        find_group_summary_recursive(nested_rows, target_group)
    end
  end

  defp find_group_summary_recursive([], _target_group), do: 0.0

  defp find_group_summary_recursive(rows, target_group) do
    case Enum.find(rows, fn row -> row["group"] == target_group end) do
      nil -> search_sub_rows(rows, target_group)
      section -> parse_col_data_value(get_in(section, ["Summary", "ColData"]))
    end
  end

  defp search_sub_rows(rows, target_group) do
    Enum.reduce_while(rows, 0.0, fn row, _acc ->
      sub_rows = get_in(row, ["Rows", "Row"]) || []
      reduce_sub_row_result(find_group_summary_recursive(sub_rows, target_group))
    end)
  end

  defp reduce_sub_row_result(+0.0), do: {:cont, 0.0}
  defp reduce_sub_row_result(value), do: {:halt, value}

  # Extract a numeric float from the second entry in a ColData array.
  # Prefers homeCurrencyAmount when present.
  defp parse_col_data_value(nil), do: 0.0
  defp parse_col_data_value([]), do: 0.0

  defp parse_col_data_value(col_data) when is_list(col_data) do
    value_entry = Enum.at(col_data, 1)

    raw =
      (value_entry && Map.get(value_entry, "homeCurrencyAmount")) ||
        (value_entry && Map.get(value_entry, "value")) ||
        "0"

    parse_float(raw)
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  # ---------------------------------------------------------------------------
  # Private helpers — metric tagging
  # ---------------------------------------------------------------------------

  defp tag_metrics(raw_metrics, realm_id, accounting_method, report_type, recorded_at) do
    Enum.map(raw_metrics, fn metric ->
      Map.merge(metric, %{
        provider: :quickbooks,
        recorded_at: recorded_at,
        metadata: %{
          realm_id: realm_id,
          accounting_method: accounting_method,
          report_type: report_type
        }
      })
    end)
  end

  defp date_to_datetime(%Date{} = date) do
    {:ok, datetime} = DateTime.new(date, ~T[00:00:00], "Etc/UTC")
    datetime
  end
end
