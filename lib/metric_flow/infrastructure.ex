defmodule MetricFlow.Infrastructure do
  @moduledoc """
  Infrastructure bounded context.

  Contains cross-cutting infrastructure concerns:
  - `Repo` - Database access
  - `Mailer` - Email delivery
  - `Vault` - Encryption/decryption
  """

  use Boundary, deps: [], exports: [Repo, Mailer, Vault]
end
