# MetricFlow.DataSync.DataProviders.QuickBooks

QuickBooks provider implementation using QuickBooks Online Accounting API. Fetches financial metrics including revenue, expenses, net_income, gross_profit, accounts_receivable, accounts_payable, and cash_on_hand from Profit and Loss and Balance Sheet reports. Transforms API response to unified metric format. Handles date range filtering, company (realm) selection, and account hierarchy. Stores metrics with provider :quickbooks.

## Functions

### fetch_metrics/2

Fetches QuickBooks financial metrics for an integration using OAuth tokens with configurable date range and company selection.

```elixir
@spec fetch_metrics(Integration.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Extract access_token from integration struct via MetricFlow.Integrations.Integration
2. Verify token is not expired using Integration.expired?/1
3. Extract realm_id (company_id) from options or integration.provider_metadata
4. Return error :missing_realm_id if realm_id not found
5. Extract date_range from options, defaulting to last 30 days
6. Format date_range to YYYY-MM-DD for QuickBooks API start_date and end_date parameters
7. Build list of reports to fetch: ProfitAndLoss and BalanceSheet
8. For each report type, build QuickBooks API request URL
9. Set base URL to https://quickbooks.api.intuit.com/v3/company/{realm_id}/reports/{ReportType}
10. Add start_date and end_date as query parameters from date_range option
11. Add accounting_method query parameter (default to Accrual)
12. Add Accept header with value application/json
13. Add OAuth access_token to Authorization header with Bearer prefix
14. Execute HTTP GET request to QuickBooks API for ProfitAndLoss report
15. Handle 401 unauthorized by returning error :unauthorized
16. Handle 403 forbidden by returning error :insufficient_permissions
17. Handle 404 not found by returning error :company_not_found
18. Handle 400 bad request by returning error with QuickBooks API error details
19. Parse successful JSON response body for ProfitAndLoss report
20. Extract Rows array from ProfitAndLoss report response
21. Navigate account hierarchy to find revenue, expenses, net_income, and gross_profit values
22. Find revenue by locating "Income" section in Rows and summing account values
23. Find expenses by locating "Expenses" section in Rows and summing account values
24. Find net_income by locating "Net Income" row in Rows
25. Find gross_profit by calculating revenue minus cost_of_goods_sold if present
26. Execute HTTP GET request to QuickBooks API for BalanceSheet report
27. Parse successful JSON response body for BalanceSheet report
28. Extract Rows array from BalanceSheet report response
29. Navigate account hierarchy to find accounts_receivable, accounts_payable, and cash_on_hand values
30. Find accounts_receivable by locating "Accounts Receivable" section in Assets
31. Find accounts_payable by locating "Accounts Payable" section in Liabilities
32. Find cash_on_hand by locating "Cash" or "Bank" accounts in Assets
33. Transform each extracted metric to unified metric format
34. Build metric map with metric_type, metric_name, value, recorded_at, metadata, provider
35. Set provider to :quickbooks for all metrics
36. Set recorded_at to end date from date_range or current timestamp
37. Convert dimension values to metadata map with realm_id, accounting_method, report_type
38. Convert metric values to appropriate numeric types (float for currency)
39. Return ok tuple with list of metric maps from both reports

**Test Assertions**:
- returns ok tuple with list of metrics for valid integration and options
- extracts access_token from integration struct
- includes OAuth token in Authorization header with Bearer prefix
- builds correct QuickBooks API URL with realm_id for ProfitAndLoss report
- builds correct QuickBooks API URL with realm_id for BalanceSheet report
- sets realm_id from options when provided
- sets realm_id from provider_metadata when not in options
- sets start_date and end_date query parameters from date_range option
- defaults to last 30 days when date_range not provided
- formats dates as YYYY-MM-DD in query parameters
- includes accounting_method query parameter with default Accrual
- allows accounting_method to be overridden in options
- includes Accept header with application/json
- fetches both ProfitAndLoss and BalanceSheet reports
- transforms QuickBooks report response to unified metric format
- sets provider to :quickbooks for all metrics
- sets recorded_at to end date from date_range
- navigates Rows hierarchy to extract revenue from Income section
- navigates Rows hierarchy to extract expenses from Expenses section
- extracts net_income from Net Income row
- calculates gross_profit from revenue and cost_of_goods_sold
- extracts accounts_receivable from Assets section
- extracts accounts_payable from Liabilities section
- extracts cash_on_hand from Cash or Bank accounts
- handles nested account hierarchy in Rows structure
- sums multiple account values within Income section for total revenue
- sums multiple account values within Expenses section for total expenses
- converts metric values to float for currency amounts
- includes realm_id in metadata
- includes accounting_method in metadata
- includes report_type in metadata (profit_and_loss or balance_sheet)
- returns error :missing_realm_id when realm_id not in options or metadata
- returns error :unauthorized when token is invalid or expired
- returns error :insufficient_permissions when token lacks accounting scope
- returns error :company_not_found when realm_id doesn't exist or user lacks access
- returns error with QuickBooks API details when request is invalid
- handles network errors gracefully with error tuple
- handles malformed JSON response with error tuple
- handles empty Rows array with zero values for metrics
- handles missing Income section by setting revenue to zero
- handles missing Expenses section by setting expenses to zero
- handles missing Net Income row by calculating from revenue minus expenses
- handles missing accounts_receivable by setting to zero
- handles missing accounts_payable by setting to zero
- handles missing cash accounts by setting cash_on_hand to zero
- handles reports with no data for date range with empty or zero values
- parses ColData array within Rows to extract numeric values
- handles Summary rows correctly without duplication
- handles multi-currency scenarios using HomeCurrencyAmount when present
- validates date_range start is before end date

### provider/0

Returns the provider atom identifier for this data provider.

```elixir
@spec provider() :: :quickbooks
```

**Process**:
1. Return :quickbooks atom

**Test Assertions**:
- returns :quickbooks atom
- return value matches Integration.provider enum value

### required_scopes/0

Returns the OAuth scopes required for fetching QuickBooks metrics.

```elixir
@spec required_scopes() :: list(String.t())
```

**Process**:
1. Return list containing "com.intuit.quickbooks.accounting"

**Test Assertions**:
- returns list with accounting scope
- scope string is properly formatted
- returned scopes are strings not atoms
- list contains exactly one scope
- scope matches QuickBooks Online API requirements
- accounting scope provides read access to financial reports

## Dependencies

- MetricFlow.Integrations.Integration
- HTTPoison
- Jason
