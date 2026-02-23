# QuickBooks Online Accounting API

Reference for the `MetricFlow.DataSync.DataProviders.QuickBooks` module.

No maintained Elixir client exists — see `docs/architecture/decisions/data_provider_apis.md`.
QuickBooks Online is handled with raw Req. QuickBooks uses standard Bearer token OAuth 2.0.

---

## API Version and Base URLs

**Production:** `https://quickbooks.api.intuit.com`
**Sandbox:** `https://sandbox-quickbooks.api.intuit.com`

All requests use API version 3. The sandbox environment is suitable for development and
uses real API flows with a test company.

Configure which environment to use in `config/runtime.exs`:

```elixir
config :metric_flow, :quickbooks_env, :production  # or :sandbox
```

```elixir
defp base_url do
  case Application.get_env(:metric_flow, :quickbooks_env, :production) do
    :sandbox -> "https://sandbox-quickbooks.api.intuit.com"
    :production -> "https://quickbooks.api.intuit.com"
  end
end
```

---

## Authentication

QuickBooks uses standard OAuth 2.0 Bearer token authentication. Access tokens expire
after **1 hour**. Refresh tokens are long-lived and rotate on each refresh (the new
refresh token must be persisted immediately after a successful refresh).

Token refresh is handled by `MetricFlow.Integrations.refresh_token/2` at the Integrations
context level. Providers do not refresh tokens.

---

## Req Configuration

```elixir
defp build_req(access_token) do
  Req.new(
    auth: {:bearer, access_token},
    headers: [{"Accept", "application/json"}],
    retry: :safe_transient,
    max_retries: 3,
    retry_delay: fn n -> trunc(Integer.pow(2, n) * 1_000) end,
    receive_timeout: 30_000
  )
end
```

The `Accept: application/json` header is critical. QuickBooks defaults to XML responses.
Without this header, the response body will be XML and Jason parsing will fail.

---

## Report Endpoints

MetricFlow fetches two reports per sync:

### Profit and Loss

```
GET {base_url}/v3/company/{realm_id}/reports/ProfitAndLoss
```

Provides: `revenue`, `expenses`, `net_income`, `gross_profit`

### Balance Sheet

```
GET {base_url}/v3/company/{realm_id}/reports/BalanceSheet
```

Provides: `accounts_receivable`, `accounts_payable`, `cash_on_hand`

### Query Parameters

| Parameter          | Description                              | Default      |
|--------------------|------------------------------------------|--------------|
| `start_date`       | Report start date (YYYY-MM-DD)           | Required     |
| `end_date`         | Report end date (YYYY-MM-DD)             | Required     |
| `accounting_method`| `Accrual` or `Cash`                      | `Accrual`    |

Both reports return their complete data in a single response. No pagination.

---

## Making the Requests

```elixir
defp fetch_profit_and_loss(req, realm_id, start_date, end_date, accounting_method) do
  url = "#{base_url()}/v3/company/#{realm_id}/reports/ProfitAndLoss"
  fetch_report(req, url, start_date, end_date, accounting_method)
end

defp fetch_balance_sheet(req, realm_id, start_date, end_date, accounting_method) do
  url = "#{base_url()}/v3/company/#{realm_id}/reports/BalanceSheet"
  fetch_report(req, url, start_date, end_date, accounting_method)
end

defp fetch_report(req, url, start_date, end_date, accounting_method) do
  params = [
    start_date: start_date,
    end_date: end_date,
    accounting_method: accounting_method
  ]

  case Req.get(req, url: url, params: params) do
    {:ok, %{status: 200, body: body}} -> {:ok, body}
    {:ok, %{status: 401}} -> {:error, :unauthorized}
    {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
    {:ok, %{status: 404}} -> {:error, :resource_not_found}
    {:ok, _} -> {:error, :network_error}
    {:error, _} -> {:error, :network_error}
  end
end
```

---

## QuickBooks Report JSON Structure

QuickBooks reports use a deeply nested `Rows` structure. Understanding the hierarchy
is essential for correct parsing.

### Structure Overview

```json
{
  "Header": {"ReportName": "ProfitAndLoss", "StartPeriod": "2025-01-01", "EndPeriod": "2025-01-31"},
  "Columns": {...},
  "Rows": {
    "Row": [
      {
        "type": "Section",
        "group": "Income",
        "Header": {"ColData": [{"value": "Income"}, {"value": ""}]},
        "Rows": {
          "Row": [
            {
              "type": "Data",
              "ColData": [{"value": "Service Revenue"}, {"value": "50000.00"}]
            }
          ]
        },
        "Summary": {
          "ColData": [{"value": "Total Income"}, {"value": "50000.00"}]
        }
      },
      {
        "type": "Section",
        "group": "NetIncome",
        "Summary": {
          "ColData": [{"value": "Net Income"}, {"value": "25000.00"}]
        }
      }
    ]
  }
}
```

### Row Types

| `type`     | Meaning                                         |
|------------|--------------------------------------------------|
| `"Section"` | Container with a `group` name, child `Rows`, and a `Summary` |
| `"Data"`    | A single line-item with a label and amount       |
| `"Summary"` | Totals row inside a `Section`                    |

### Group Names

Key `group` values in ProfitAndLoss:

| Group Name          | Maps To                     |
|---------------------|-----------------------------|
| `"Income"`          | Revenue                     |
| `"COGS"`            | Cost of Goods Sold          |
| `"GrossProfit"`     | Gross Profit                |
| `"Expenses"`        | Operating Expenses          |
| `"NetIncome"`       | Net Income                  |

Key `group` values in BalanceSheet:

| Group Name          | Maps To                          |
|---------------------|----------------------------------|
| `"CurrentAssets"`   | Current assets (includes AR)     |
| `"CurrentLiabilities"` | Current liabilities (includes AP) |
| `"BankAccounts"`    | Cash and bank accounts           |

---

## Parsing Strategy

Use `Summary` rows rather than summing `Data` rows. The summary contains the section
total and avoids double-counting when QuickBooks includes both subtotals and a grand total.

```elixir
defp extract_profit_and_loss(body, realm_id, end_date) do
  rows = get_in(body, ["Rows", "Row"]) || []

  revenue    = find_section_total(rows, "Income")
  expenses   = find_section_total(rows, "Expenses")
  net_income = find_net_income_total(rows)
  cogs       = find_section_total(rows, "COGS")

  gross_profit =
    if cogs > 0.0,
      do: revenue - cogs,
      else: find_section_total(rows, "GrossProfit")

  meta = %{
    realm_id: realm_id,
    report_type: :profit_and_loss,
    accounting_method: "Accrual"
  }

  recorded_at = parse_date_to_datetime(end_date)

  [
    metric(:revenue,      "revenue",      revenue,      recorded_at, meta),
    metric(:expenses,     "expenses",     expenses,     recorded_at, meta),
    metric(:net_income,   "net_income",   net_income,   recorded_at, meta),
    metric(:gross_profit, "gross_profit", gross_profit, recorded_at, meta)
  ]
end

defp find_section_total(rows, group_name) do
  case Enum.find(rows, fn r -> r["group"] == group_name end) do
    nil ->
      0.0

    section ->
      # Read from the Summary ColData[1] (index 1 is the amount column)
      section
      |> get_in(["Summary", "ColData"])
      |> then(fn col_data -> if col_data, do: Enum.at(col_data, 1), else: nil end)
      |> then(fn cell -> if cell, do: cell["value"], else: nil end)
      |> parse_currency()
  end
end

defp find_net_income_total(rows) do
  # NetIncome group may be a top-level Section or just a Summary row
  case Enum.find(rows, fn r -> r["group"] == "NetIncome" end) do
    nil -> 0.0
    section -> section |> get_in(["Summary", "ColData"]) |> Enum.at(1) |> then(& &1["value"]) |> parse_currency()
  end
end

defp extract_balance_sheet(body, realm_id, end_date) do
  rows = get_in(body, ["Rows", "Row"]) || []

  accounts_receivable = find_named_data(rows, "Accounts Receivable")
  accounts_payable    = find_named_data(rows, "Accounts Payable")
  cash_on_hand        = find_section_total(rows, "BankAccounts")

  meta = %{
    realm_id: realm_id,
    report_type: :balance_sheet,
    accounting_method: "Accrual"
  }

  recorded_at = parse_date_to_datetime(end_date)

  [
    metric(:accounts_receivable, "accounts_receivable", accounts_receivable, recorded_at, meta),
    metric(:accounts_payable,    "accounts_payable",    accounts_payable,    recorded_at, meta),
    metric(:cash_on_hand,        "cash_on_hand",        cash_on_hand,        recorded_at, meta)
  ]
end

# Walk the entire row tree to find a named Data row
defp find_named_data(rows, label) do
  Enum.reduce_while(rows, 0.0, fn row, _acc ->
    cond do
      row["type"] == "Data" ->
        col_data = row["ColData"] || []
        row_label = col_data |> Enum.at(0) |> then(fn c -> if c, do: c["value"], else: "" end)
        row_value = col_data |> Enum.at(1) |> then(fn c -> if c, do: c["value"], else: "0" end)

        if row_label == label do
          {:halt, parse_currency(row_value)}
        else
          {:cont, 0.0}
        end

      nested_rows = get_in(row, ["Rows", "Row"]) ->
        {:cont, find_named_data(nested_rows, label)}

      true ->
        {:cont, 0.0}
    end
  end)
end

defp parse_currency(nil), do: 0.0
defp parse_currency(""), do: 0.0
defp parse_currency(val) when is_float(val), do: val
defp parse_currency(val) when is_integer(val), do: val / 1.0
defp parse_currency(val) when is_binary(val) do
  case Float.parse(val) do
    {f, _} -> f
    :error -> 0.0
  end
end
```

---

## Combining Both Reports

```elixir
def fetch_metrics(%Integration{} = integration, opts) do
  with false <- Integration.expired?(integration),
       {:ok, realm_id} <- extract_realm_id(integration, opts) do
    req = Keyword.get(opts, :req, build_req(integration.access_token))
    {start_date, end_date} = default_date_range(opts)
    accounting_method = Keyword.get(opts, :accounting_method, "Accrual")

    with {:ok, pl_body} <- fetch_profit_and_loss(req, realm_id, start_date, end_date, accounting_method),
         {:ok, bs_body} <- fetch_balance_sheet(req, realm_id, start_date, end_date, accounting_method) do
      pl_metrics = extract_profit_and_loss(pl_body, realm_id, end_date)
      bs_metrics = extract_balance_sheet(bs_body, realm_id, end_date)
      {:ok, pl_metrics ++ bs_metrics}
    end
  else
    true -> {:error, :token_expired}
    {:error, reason} -> {:error, reason}
  end
end
```

---

## provider_metadata

Store `realm_id` (the QuickBooks company ID) in `integration.provider_metadata["realm_id"]`.
Intuit provides the `realm_id` in the OAuth callback as the `realmId` parameter.

```elixir
defp extract_realm_id(integration, opts) do
  case Keyword.get(opts, :realm_id) ||
       get_in(integration.provider_metadata, ["realm_id"]) do
    nil -> {:error, :missing_realm_id}
    id  -> {:ok, to_string(id)}
  end
end
```

---

## required_scopes/0

```elixir
def required_scopes, do: ["com.intuit.quickbooks.accounting"]
```

---

## Multi-Currency

If a QuickBooks company uses multi-currency, report values may be in the foreign currency.
QuickBooks includes a `HomeCurrencyAmount` field in some ColData entries when the base
currency is different from the transaction currency. Use `HomeCurrencyAmount` when present:

```elixir
defp extract_col_value(col_data_entry) do
  case col_data_entry do
    %{"attributes" => %{"amount" => amount}} -> parse_currency(amount)
    %{"value" => value} -> parse_currency(value)
    nil -> 0.0
  end
end
```

For simplicity in the initial implementation, the MetricFlow spec does not require
multi-currency support. This is a future enhancement.
