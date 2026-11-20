# priv/repo/seeds.exs
#
# Seeds believable sample data for development and test.
#
# Dev-only password for every seeded user: `hello world!`
# Sign in at /users/log-in with any of:
#   joel@example.com     — agency owner of "Anderson the Fish",
#                          also a member of "Anderson Retail Co."
#   client@example.com   — owner of client account "Anderson Retail Co."
#   direct@example.com   — owner of direct client account "Direct Marketer LLC"
#
# Idempotent: `mix run priv/repo/seeds.exs` (or `mix ecto.reset`) can be run
# repeatedly with no duplicates and no errors. Refuses to run outside :dev
# and :test, so UAT and prod databases are never touched.

seed_env =
  cond do
    Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) -> Mix.env()
    true -> :prod
  end

unless seed_env in [:dev, :test] do
  IO.puts(:stderr, "[seeds] refusing to run in #{inspect(seed_env)} — dev/test only.")
  exit({:shutdown, 1})
end

alias MetricFlow.Accounts
alias MetricFlow.Accounts.Account
alias MetricFlow.Accounts.AccountMember
alias MetricFlow.Agencies
alias MetricFlow.Agencies.AgencyClientAccessGrant
alias MetricFlow.Ai.ChatMessage
alias MetricFlow.Ai.ChatSession
alias MetricFlow.Ai.Insight
alias MetricFlow.Correlations.CorrelationJob
alias MetricFlow.Correlations.CorrelationResult
alias MetricFlow.Dashboards.Dashboard
alias MetricFlow.Dashboards.DashboardVisualization
alias MetricFlow.Dashboards.Visualization
alias MetricFlow.Integrations.Integration
alias MetricFlow.Metrics.Metric
alias MetricFlow.Repo
alias MetricFlow.Users
alias MetricFlow.Users.Scope
alias MetricFlow.Users.User
alias MetricFlow.Users.UserToken

import Ecto.Query

dev_password = "hello world!"

# --- user helpers -----------------------------------------------------------

find_or_create_user = fn email, account_name ->
  case Users.get_user_by_email(email) do
    %User{} = u ->
      u

    nil ->
      {:ok, user} =
        Users.register_user(%{
          email: email,
          password: dev_password,
          account_name: account_name
        })

      {token, user_token} = UserToken.build_email_token(user, "login")
      Repo.insert!(user_token)
      {:ok, {confirmed, _expired}} = Users.login_user_by_magic_link(token)

      {:ok, {with_pw, _tokens}} =
        Users.update_user_password(confirmed, %{password: dev_password})

      with_pw
  end
end

find_or_create_account = fn name, slug, type, owner ->
  case Repo.get_by(Account, name: name) do
    %Account{} = a ->
      a

    nil ->
      {:ok, account} =
        Accounts.create_team_account(Scope.for_user(owner), %{name: name, slug: slug}, type)

      account
  end
end

ensure_member = fn account, user, role ->
  unless Repo.get_by(AccountMember, account_id: account.id, user_id: user.id) do
    %AccountMember{}
    |> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: role})
    |> Repo.insert!()
  end
end

# --- users ------------------------------------------------------------------

joel = find_or_create_user.("joel@example.com", "Joel Anderson")
client_user = find_or_create_user.("client@example.com", "Anderson Retail")
direct_user = find_or_create_user.("direct@example.com", "Direct Marketer")

# --- accounts ---------------------------------------------------------------

agency = find_or_create_account.("Anderson the Fish", "anderson-the-fish", :agency, joel)

retail =
  find_or_create_account.("Anderson Retail Co.", "anderson-retail-co", :client, client_user)

_direct_acct =
  find_or_create_account.("Direct Marketer LLC", "direct-marketer-llc", :client, direct_user)

# Joel joins the client account as an account_manager so he can work on it.
ensure_member.(retail, joel, :account_manager)

# Agency manages the client account at :account_manager.
grant_exists? =
  Repo.exists?(
    from(g in AgencyClientAccessGrant,
      where: g.agency_account_id == ^agency.id and g.client_account_id == ^retail.id
    )
  )

unless grant_exists? do
  joel_agency_scope = Scope.for_user(joel) |> Scope.put_account_id(agency.id)

  {:ok, _grant} =
    Agencies.grant_client_account_access(
      joel_agency_scope,
      agency.id,
      retail.id,
      :account_manager,
      false
    )
end

# --- integrations on Anderson Retail Co. ------------------------------------
#
# Google Analytics and Google Ads share one `:google` integration (see
# MetricFlow.Integrations). Facebook Ads and QuickBooks each have their own.
# No real tokens — these placeholders only exist so the UI shows "connected".

fake_expiry = DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second)

ensure_integration = fn provider, granted_scopes, metadata ->
  unless Repo.get_by(Integration, account_id: retail.id, provider: provider) do
    %Integration{}
    |> Integration.changeset(%{
      account_id: retail.id,
      user_id: client_user.id,
      provider: provider,
      access_token: "seed-#{provider}-access-token",
      refresh_token: "seed-#{provider}-refresh-token",
      expires_at: fake_expiry,
      granted_scopes: granted_scopes,
      provider_metadata: metadata
    })
    |> Repo.insert!()
  end
end

ensure_integration.(
  :google,
  [
    "https://www.googleapis.com/auth/analytics.readonly",
    "https://www.googleapis.com/auth/adwords"
  ],
  %{
    "email" => "client@example.com",
    "property_id" => "properties/000000001",
    "customer_id" => "0000000001"
  }
)

ensure_integration.(:facebook_ads, ["ads_read", "business_management"], %{
  "ad_account_id" => "act_000000001"
})

ensure_integration.(:quickbooks, ["com.intuit.quickbooks.accounting"], %{
  "realm_id" => "000000001"
})

# --- ~90 days of daily metrics with believable trends ----------------------

metric_defs = [
  {"ga_sessions", "traffic", :google_analytics, 520.0, 25.0, 0.06},
  {"ga_conversions", "traffic", :google_analytics, 28.0, 6.0, 0.04},
  {"gads_clicks", "advertising", :google_ads, 180.0, 20.0, 0.03},
  {"gads_cost", "advertising", :google_ads, 410.0, 30.0, 0.02},
  {"fb_impressions", "advertising", :facebook_ads, 12_000.0, 900.0, 0.01},
  {"fb_ad_spend", "advertising", :facebook_ads, 220.0, 25.0, 0.015},
  {"qb_revenue", "financial", :quickbooks, 1850.0, 220.0, 0.025},
  {"qb_expenses", "financial", :quickbooks, 620.0, 80.0, 0.01}
]

today = Date.utc_today()
day_offsets = 0..89

for {name, type, provider, base, noise, trend} <- metric_defs, d <- day_offsets do
  date = Date.add(today, -d)
  recorded_at = DateTime.new!(date, ~T[12:00:00.000000], "Etc/UTC")

  already =
    from(m in Metric,
      where:
        m.account_id == ^retail.id and m.metric_name == ^name and
          m.recorded_at == ^recorded_at,
      limit: 1
    )
    |> Repo.one()

  unless already do
    # Older days are smaller; recent days higher — gentle upward trend plus a
    # weekly wiggle so the charts don't look synthetic.
    days_from_oldest = 89 - d
    trended = base * (1.0 + trend * days_from_oldest / 10.0)
    wiggle = :math.sin(d / 7.0) * noise

    %Metric{}
    |> Metric.changeset(%{
      account_id: retail.id,
      user_id: client_user.id,
      metric_name: name,
      normalized_metric_name: name,
      metric_type: type,
      provider: provider,
      value: trended + wiggle,
      recorded_at: recorded_at,
      dimensions: %{}
    })
    |> Repo.insert!()
  end
end

# --- dashboards + visualizations -------------------------------------------

ensure_dashboard = fn name, viz_specs ->
  case Repo.get_by(Dashboard, account_id: retail.id, name: name) do
    %Dashboard{} = d ->
      d

    nil ->
      dash =
        %Dashboard{user_id: client_user.id, account_id: retail.id}
        |> Dashboard.changeset(%{
          name: name,
          description: "Seeded sample dashboard",
          date_range: "90",
          a2ui_spec: %{}
        })
        |> Repo.insert!()

      viz_specs
      |> Enum.with_index(0)
      |> Enum.each(fn {{vname, chart_type, metric_name}, position} ->
        viz =
          %Visualization{user_id: client_user.id, account_id: retail.id}
          |> Visualization.changeset(%{
            name: vname,
            vega_spec: %{"chart_type" => chart_type, "metric_name" => metric_name}
          })
          |> Repo.insert!()

        %DashboardVisualization{}
        |> DashboardVisualization.changeset(%{
          dashboard_id: dash.id,
          visualization_id: viz.id,
          position: position
        })
        |> Repo.insert!()
      end)

      dash
  end
end

ensure_dashboard.("Growth Overview", [
  {"Sessions trend", "line", "ga_sessions"},
  {"Conversions trend", "line", "ga_conversions"},
  {"Revenue trend", "area", "qb_revenue"}
])

ensure_dashboard.("Paid Media", [
  {"Google Ads spend", "line", "gads_cost"},
  {"Facebook spend", "line", "fb_ad_spend"}
])

# --- correlation jobs, results + goals -------------------------------------

now_dt = DateTime.utc_now()

ensure_correlation_job = fn goal_metric_name ->
  case Repo.get_by(CorrelationJob,
         account_id: retail.id,
         goal_metric_name: goal_metric_name
       ) do
    %CorrelationJob{} = j ->
      j

    nil ->
      %CorrelationJob{}
      |> CorrelationJob.changeset(%{
        account_id: retail.id,
        status: :completed,
        goal_metric_name: goal_metric_name,
        time_window: :days_90,
        data_window_start: Date.add(today, -89),
        data_window_end: today,
        data_points: 90,
        results_count: 3,
        started_at: now_dt,
        completed_at: now_dt
      })
      |> Repo.insert!()
  end
end

revenue_job = ensure_correlation_job.("qb_revenue")
_conv_job = ensure_correlation_job.("ga_conversions")

correlation_rows = [
  {"gads_cost", "qb_revenue", :google_ads, 0.82, 3},
  {"fb_ad_spend", "qb_revenue", :facebook_ads, 0.68, 5},
  {"ga_sessions", "qb_revenue", :google_analytics, 0.74, 2}
]

for {metric_name, goal, provider, coef, lag} <- correlation_rows do
  already =
    Repo.get_by(CorrelationResult,
      account_id: retail.id,
      correlation_job_id: revenue_job.id,
      metric_name: metric_name,
      goal_metric_name: goal
    )

  unless already do
    %CorrelationResult{}
    |> CorrelationResult.changeset(%{
      account_id: retail.id,
      correlation_job_id: revenue_job.id,
      metric_name: metric_name,
      goal_metric_name: goal,
      coefficient: coef,
      optimal_lag: lag,
      data_points: 90,
      provider: provider,
      calculated_at: now_dt
    })
    |> Repo.insert!()
  end
end

# --- insights --------------------------------------------------------------

insight_defs = [
  {"Shift budget toward Google Ads",
   "Google Ads spend correlates strongly with revenue at a 3-day lag (r=0.82). " <>
     "Consider a 10–15% budget reallocation from channels with weaker correlation.",
   :budget_increase, 0.85},
  {"Monitor Facebook campaigns",
   "Facebook ad spend shows a moderate positive correlation (r=0.68) with revenue at a " <>
     "5-day lag — worth watching before any budget change.", :monitoring, 0.72}
]

for {summary, content, type, confidence} <- insight_defs do
  unless Repo.get_by(Insight, account_id: retail.id, summary: summary) do
    %Insight{}
    |> Insight.changeset(%{
      account_id: retail.id,
      summary: summary,
      content: content,
      suggestion_type: type,
      confidence: confidence,
      generated_at: now_dt,
      metadata: %{}
    })
    |> Repo.insert!()
  end
end

# --- a saved report (stored as a shareable, named visualization) -----------

unless Repo.get_by(Visualization, account_id: retail.id, name: "Q4 revenue vs. ad spend") do
  %Visualization{user_id: client_user.id, account_id: retail.id}
  |> Visualization.changeset(%{
    name: "Q4 revenue vs. ad spend",
    shareable: true,
    vega_spec: %{
      "chart_type" => "line",
      "metrics" => ["qb_revenue", "gads_cost", "fb_ad_spend"],
      "title" => "Q4 revenue vs. ad spend"
    }
  })
  |> Repo.insert!()
end

# --- 5 chat sessions with short histories ----------------------------------

chat_sessions = [
  {"Q4 revenue outlook and drivers",
   [
     {:user, "What are the main drivers of our Q4 revenue so far?"},
     {:assistant,
      "Google Ads spend and organic sessions both correlate strongly with revenue " <>
        "this quarter, with Google Ads leading by about 3 days."},
     {:user, "Anything negative to watch?"},
     {:assistant,
      "Facebook ad spend is a weaker, slower lead. If you trim it, do so in small " <>
        "steps so the 5-day lag doesn't surprise you."}
   ]},
  {"Marketing ROI by channel",
   [
     {:user, "Which channel gave us the best ROI last month?"},
     {:assistant,
      "Google Ads produced the strongest revenue correlation (r=0.82) with a 3-day " <>
        "lag. Facebook was moderate (r=0.68)."}
   ]},
  {"Customer retention trends",
   [
     {:user, "How is retention trending?"},
     {:assistant,
      "Repeat sessions are up roughly 6% over the trailing 30 days. Conversions " <>
        "from returning visitors are climbing faster than from new ones."}
   ]},
  {"Cash flow and runway analysis",
   [
     {:user, "Do we have a runway concern?"},
     {:assistant,
      "Expenses are flat week-over-week while revenue trends up ~2.5% weekly. At the " <>
        "current pace runway is comfortable through the quarter."}
   ]},
  {"Top product opportunities",
   [
     {:user, "What should we push next quarter?"},
     {:assistant,
      "Based on conversion mix and correlation lags, SKUs promoted through Google " <>
        "Ads convert faster than those on Facebook — lean into the top 3."}
   ]}
]

for {title, messages} <- chat_sessions do
  session =
    case Repo.get_by(ChatSession,
           account_id: retail.id,
           user_id: client_user.id,
           title: title
         ) do
      %ChatSession{} = s ->
        s

      nil ->
        s =
          %ChatSession{}
          |> ChatSession.changeset(%{
            user_id: client_user.id,
            account_id: retail.id,
            title: title,
            context_type: :general,
            status: :active,
            shared: false
          })
          |> Repo.insert!()

        Enum.each(messages, fn {role, content} ->
          %ChatMessage{}
          |> ChatMessage.changeset(%{
            chat_session_id: s.id,
            role: role,
            content: content
          })
          |> Repo.insert!()
        end)

        s
    end

  _ = session
end

if seed_env == :dev do
  IO.puts("""

  ==========================================
   Seeded sample data
  ==========================================
  Password for every seeded user: #{dev_password}

  Users:
    joel@example.com    (agency owner, "Anderson the Fish")
    client@example.com  (owner, "Anderson Retail Co.")
    direct@example.com  (direct marketer)

  Sign in:  http://localhost:4070/users/log-in
  ==========================================
  """)
end
