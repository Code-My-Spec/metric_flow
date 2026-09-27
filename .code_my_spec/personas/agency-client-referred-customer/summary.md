# Jordan — Agency Client

## Role

Jordan owns or runs marketing decisions for a small or local business that
hired a marketing/reporting agency. Jordan never signs up for the reporting
platform directly: access arrives as a branded, white-labeled login handed
over by the agency, and the tool's cost never appears as its own line item —
it is folded into whatever Jordan pays the agency. The platform underneath is
usually invisible; the agency's brand is what Jordan sees on every login and
invoice.

## Goals

- See performance numbers tied to the money being spent — CPAs, ROAS,
  conversions by campaign — clear enough to judge whether the agency
  relationship is working.
- Get to that view with as little setup as possible: click a link the agency
  sent, not configure a new account.
- Keep billing simple — one predictable payment to the agency, not a
  separate SaaS subscription to track and reconcile.

## Pain Points

- Branded client portals occasionally break or confuse first-time users —
  login/connection issues and unclear onboarding documentation show up
  repeatedly in portal reviews.
- Distrust builds fast when an agency won't show real performance detail;
  peers explicitly flag "can't tell you which sales came from ads" as a red
  flag worth leaving over.
- Fear of losing access to historical dashboards and reporting if the
  agency relationship ends, because the login and underlying ad accounts
  are controlled by the agency, not owned by Jordan.

## Context

- Non-technical operator of a small or local business — not a marketer by
  trade, and the dashboard has to work for someone with "limited analytics
  experience."
- Touches the reporting tool occasionally (a monthly review, an ad hoc
  check before a renewal decision), not daily.
- Has no direct line to the platform vendor. The agency is the only
  billing and support contact Jordan has ever dealt with for this tool.

## Decision Drivers

- Transparency: does the agency show real numbers, or hide behind vague
  reporting? This is the top reason cited for firing an agency.
- Continuity: will Jordan still see this data and keep some form of access
  if the agency relationship ends? Multiple guides exist specifically to
  help small business owners avoid losing dashboard/account access when
  switching agencies.
- Billing simplicity: one line item from the agency beats reconciling a
  separate SaaS invoice — reseller/rebilling platforms are built explicitly
  around this expectation, marking up usage at the platform level so the
  client only ever sees the agency's price.

## Jobs to Be Done

"When my agency sends me a login to see my numbers, I want a dashboard I can
understand without training, so I can tell whether the money I'm spending on
marketing is actually working."

## Evidence

- Branded, white-labeled portal is the norm and is built for non-technical
  users: Vendasta white label reporting guide; Cloud Campaign white label
  client dashboard guide; Zoho white label reporting tool page;
  AgencyAnalytics G2 listing ("clients get their own branded login").
- Client login normally arrives via email invite into a personalized,
  branded dashboard, not a self-serve signup: G2 "What is a Client Portal?"
  explainer; Zite "7 Best Agency Client Dashboards" review.
- Clients want and expect real ad-performance detail (CPAs, ROAS, per-
  campaign conversions) from their dashboard access, and its absence is a
  named red flag: r/AskMarketing thread, "What should my marketing agency
  be providing?"
- Clients grow distrustful over ownership/visibility of their own
  marketing accounts and data: r/smallbusiness thread, "I'm sick of my
  marketing agency."
- Billing is commonly structured as the agency rebilling/marking-up the
  underlying platform cost through its own payment processor, so the
  client only ever sees the agency's invoice: Salesforge white label
  software roundup; ClickFunnels GoHighLevel pricing explainer; HighLevel
  support portal, "Rebilling, Reselling, and Wallets Explained";
  netpartners.marketing on SaaS Mode rebilling through Stripe at a markup.
- Losing dashboard/account access when switching agencies is a widely
  documented fear, with multiple independent guides written specifically to
  help clients retain ownership before parting ways with an agency:
  mrktcorrect "How to Switch Marketing Agencies Without Losing Data";
  SearchPod equivalent guide; Migliore Agenzia equivalent guide; Wheels Up
  Collective "Don't Let Agencies Hold Your Data Hostage"; Pixel This
  Marketing, "When Your Marketing Agency Loses Account Access."
- Portal login and onboarding friction is a recurring, if secondary,
  complaint in client portal reviews: G2 Client Portal category reviews
  ("issues connecting to the portal," documentation needs to be clearer).
