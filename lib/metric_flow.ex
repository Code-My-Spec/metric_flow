defmodule MetricFlow do
  @moduledoc """
  MetricFlow keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.

  ## Boundary Architecture

  Each context defines its own boundary with explicit dependencies:

  - `MetricFlow.Infrastructure` - Cross-cutting concerns (Repo, Mailer, Vault)
  - `MetricFlow.Users` - User management (deps: Infrastructure)
  - `MetricFlow.Accounts` - Account/team management (deps: Users, Infrastructure)
  - `MetricFlow.Invitations` - Invitation workflow (deps: Users, Accounts, Infrastructure)
  - `MetricFlow.Integrations` - OAuth integrations (deps: Users, Infrastructure)
  - `MetricFlow.UserPreferences` - User settings (deps: Users, Infrastructure)
  """

  use Boundary,
    deps: [],
    exports: [
      # Re-export child boundary exports for siblings (MetricFlowWeb) to access
      {Infrastructure, []},
      {Users, []},
      {Accounts, []},
      {Invitations, []},
      {Integrations, []},
      {UserPreferences, []}
    ]
end
