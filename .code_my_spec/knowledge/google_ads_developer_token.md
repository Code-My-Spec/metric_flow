# Google Ads API Developer Token Application

Reference for applying for and maintaining a Google Ads API developer token.

---

## Access Levels

| Level | Accounts | Daily Ops Limit | RMF Required | Review |
|-------|----------|----------------|--------------|--------|
| Test Account | Test only | 15,000 | No | Instant |
| Explorer | Production | 2,880 | No | Automatic |
| Basic | Production | 15,000 | No | ~2 business days |
| Standard | Production | Unlimited | Yes | ~10 business days |

MetricFlow is a **reporting-only** tool — it reads campaign data but never creates or modifies ads. Basic Access is sufficient.

---

## Application Requirements

### Form Fields

1. **MCC ID** — Manager account ID (format: `123-456-7890`)
2. **Contact email** — Must be monitored; use a role-based alias (e.g., `api@metric-flow.app`)
3. **Website URL** — Must be live and functional at time of review
4. **Business model description** — Multi-sentence explanation of how you use Google Ads
5. **Design document** — PDF/DOC showing tool wireframes and feature descriptions
6. **User access type** — Internal, external, or both
7. **Token sharing** — Whether you'll use another developer's token
8. **App conversion tracking** — Whether you'll use conversion tracking API

### Website Requirements

- **Privacy Policy** at `/privacy` — must include Google API Services Limited Use disclosure
- **Terms of Service** at `/terms`
- **Homepage** with app description and links to both legal pages
- **Footer** with privacy/terms links on all pages

### Design Document

The design doc must be PDF, DOC, or RTF format. Include:

1. **Tool overview** — What the tool does and who uses it
2. **Architecture diagram** — How data flows from Google Ads to the user
3. **Wireframes/screenshots** — Every screen that displays or interacts with Google Ads data
4. **Feature descriptions** — For each screen, describe every button, link, and data element
5. **API usage details** — Which API endpoints, what data is fetched, how often
6. **Data handling** — How Google data is stored, secured, and deleted
7. **OAuth flow** — How users authorize and what scopes are requested

Tips:
- Wireframes plus detailed descriptions are often sufficient for Basic access
- Show every screen, even if low-fidelity
- Be specific about what happens when buttons are clicked
- Include data examples showing the metrics you'll display

### OAuth Consent Screen

- Must link to privacy policy URL
- All domains must be verified in Google Search Console
- App name must not include "Google" or be confusable with Google products
- Logo: 120x120 px square, JPG/PNG/BMP

---

## MetricFlow's Use Case

MetricFlow is a **read-only reporting and analytics platform**. It:

1. Connects to Google Ads via OAuth (offline access, adwords scope)
2. Fetches campaign performance metrics via `searchStream` API (v23)
3. Stores metrics in a normalized database for cross-platform analysis
4. Displays unified dashboards combining Google Ads with other platforms
5. Runs correlation analysis between Google Ads metrics and business outcomes
6. Generates AI-powered insights and recommendations

**It never creates, modifies, or manages campaigns, ads, or keywords.**

### API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `customers/{id}/googleAds:searchStream` | POST | Fetch campaign metrics via GAQL |

### Metrics Fetched

- impressions, clicks, cost_micros, conversions, ctr, average_cpc, conversions_value
- Broken down by campaign.name, segments.date
- Default range: last 30 days

### Data Sync Schedule

- Automated daily sync at 2:00 AM UTC
- Manual sync available via UI button
- Oban job queue with deduplication (1-hour uniqueness window)

---

## Common Rejection Reasons

1. Website not live or not functioning
2. Vague use case description
3. Unreachable contact email
4. Little or no ad spend history on manager account
5. No managed accounts linked under MCC
6. Missing privacy policy or terms of service
7. OAuth consent screen not configured properly
8. Impermissible use case (not related to campaign creation, management, or reporting)

---

## Sources

- [Developer Token Docs](https://developers.google.com/google-ads/api/docs/api-policy/developer-token)
- [Access Levels and Permissible Use](https://developers.google.com/google-ads/api/docs/api-policy/access-levels)
- [Access Levels and RMF](https://developers.google.com/google-ads/api/docs/productionize/access-levels)
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
- [Pete Bowen - Building Custom Tools](https://pete-bowen.com/building-custom-tools-with-the-google-ads-api)
