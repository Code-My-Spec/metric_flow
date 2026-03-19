# priv/repo/qa_seeds_448.exs
#
# Supplemental QA seeds for Story 448: View Correlation Analysis Results (Raw Mode)
# Creates a qa-empty@example.com user with no correlation data for testing no-data states.
# Idempotent — safe to run multiple times.
#
# Usage: mix run priv/repo/qa_seeds_448.exs

alias MetricFlow.{Repo, Users}
alias MetricFlow.Users.{Scope, UserToken}

import Ecto.Query

defmodule QaSeed448 do
  def find_or_create_user(email, password, account_name) do
    case Users.get_user_by_email(email) do
      nil ->
        {:ok, user} =
          Users.register_user(%{
            email: email,
            password: password,
            account_name: account_name
          })

        {token, user_token} = UserToken.build_email_token(user, "login")
        Repo.insert!(user_token)

        {:ok, {confirmed_user, _expired}} = Users.login_user_by_magic_link(token)

        {:ok, {user_with_password, _}} =
          Users.update_user_password(confirmed_user, %{password: password})

        IO.puts("  Created and confirmed: #{email}")
        user_with_password

      existing ->
        IO.puts("  Exists: #{email} (confirmed_at=#{existing.confirmed_at})")
        existing
    end
  end
end

IO.puts("\n--- QA Empty User (no correlation data) ---")
_qa_empty = QaSeed448.find_or_create_user("qa-empty@example.com", "hello world!", "Empty Personal")

IO.puts("""

==========================================
 QA Seed 448 — Credentials
==========================================

Empty user: qa-empty@example.com / hello world!
  - Personal account only, no correlation data
  - Used for testing no-data empty state (Scenario 4)
  - Used for testing insufficient data error (Scenario 8)

URL: http://localhost:4070/users/log-in
==========================================
""")
