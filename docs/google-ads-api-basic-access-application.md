# Google Ads API — Basic Access Application

## Company Name

MetricFlow

## Business Model

My company operates MetricFlow, a SaaS analytics platform that helps small and mid-size businesses understand their advertising and financial performance in one place. Our customers connect their Google Ads, Facebook Ads, Google Analytics, and QuickBooks accounts to view unified dashboards and reports.

We also offer a white-label version of MetricFlow for marketing agencies. Agencies use MetricFlow under their own brand to provide reporting dashboards to their clients. Each agency manages multiple client accounts, each of which may have its own Google Ads account connected.

MetricFlow does **not** create, modify, or manage ads on behalf of users. We are a **read-only reporting and analytics tool**. We pull campaign performance metrics from the Google Ads API so our users can visualize trends, generate reports, and receive AI-powered insights about their ad spend.

## Tool Access/Use

MetricFlow is accessed by two types of users through our web application:

1. **Business owners** — Individual users who connect their own Google Ads account to view their campaign performance alongside other business metrics (Facebook Ads, Google Analytics, QuickBooks). They interact with dashboards and can generate PDF reports for download.

2. **Agency teams** — Marketing agencies that manage multiple client accounts. Agency admins invite team members who can then view reporting dashboards for any client account they have access to. Agencies use our white-label feature to present MetricFlow under their own brand to their clients.

All users authenticate via email magic link or Google OAuth login. Each user can only see data from Google Ads accounts they have explicitly connected or been granted access to through their agency. There is no public or unauthenticated access to any Google Ads data.

Our tool is externally accessible at [your-domain]. Screenshots and mockups of the reporting interface are included below.

## Tool Design

MetricFlow syncs Google Ads campaign performance data once daily into our PostgreSQL database using a background job scheduler (not in real-time). The sync process works as follows:

1. A scheduled background job runs daily for each connected Google Ads integration.
2. The job checks whether the user's OAuth access token is still valid. If expired, it refreshes the token using the stored refresh token.
3. The job calls the Google Ads API `searchStream` endpoint with a GAQL query to fetch campaign-level metrics for the sync period.
4. Metrics are normalized into our unified schema and stored in our database.
5. The web UI reads from the database to display dashboards — it never calls the Google Ads API directly.

Users interact with the data through:

- **Dashboards** — Time series charts, summary cards, and custom layouts showing campaign performance over selectable date ranges.
- **Correlation analysis** — Cross-provider insights (e.g., how Google Ads spend relates to QuickBooks revenue).
- **AI-powered insights** — Automated analysis and natural language Q&A about ad performance trends.
- **PDF report generation** — Downloadable reports summarizing campaign performance for a given period.

We store OAuth tokens encrypted at rest using AES-256-GCM encryption. Tokens are only decrypted at the moment of API access and are never exposed to the frontend or logged.

## API Services Called

We call a single Google Ads API endpoint:

**`googleAds:searchStream`** — We use the `searchStream` method on the `GoogleAdsService` to pull campaign performance reports. This is the only API service we call.

Example GAQL query:

```sql
SELECT
  campaign.id,
  campaign.name,
  campaign.status,
  segments.date,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.ctr,
  metrics.average_cpc,
  metrics.conversions_value
FROM campaign
WHERE segments.date BETWEEN '2025-01-01' AND '2025-01-31'
  AND campaign.status != 'REMOVED'
ORDER BY segments.date DESC
```

We **do not** call any mutating endpoints. We do not create, update, pause, or delete ads, ad groups, campaigns, or any other Google Ads resources. Our access is strictly read-only for reporting purposes.

**Resources accessed:**
- `campaign` — Campaign names, IDs, and status
- `metrics` — Impressions, clicks, cost, conversions, CTR, average CPC, conversion value
- `segments.date` — Date-level granularity for time series reporting

**Authentication:**
- OAuth 2.0 bearer token (per-user, obtained during account connection)
- Developer token (application-level, included in request headers)

## Tool Mockups
>
> 1. **Integration connection page** — Where users connect their Google Ads account via OAuth
> 2. **Dashboard view** — Main reporting dashboard showing Google Ads metrics (impressions, clicks, spend, conversions) as time series charts and summary cards
> 3. **Date range selector** — Showing how users filter metrics by time period
> 4. **PDF report preview** — Example of a generated report
> 5. **Agency view** — Showing how agency users switch between client accounts
>
> Google specifically notes: "if your tool is externally accessible, please make sure you include screenshots or mock-ups of your tool"
