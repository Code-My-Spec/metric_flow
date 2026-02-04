defmodule MetricFlow do
  @moduledoc """
  MetricFlow keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  use Boundary,
    deps: [],
    exports: [
      # Context facades
      Users,
      Accounts,
      Invitations,
      Integrations,
      UserPreferences,
      # Public schemas/structs
      Users.User,
      Users.Scope,
      Accounts.Account,
      Accounts.Member,
      Invitations.Invitation,
      Integrations.Integration,
      UserPreferences.UserPreference,
      # Infrastructure
      Repo,
      Mailer,
      Authorization
    ]
end
