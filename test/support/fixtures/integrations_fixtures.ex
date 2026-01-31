defmodule MetricFlow.IntegrationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MetricFlow.Integrations` context.
  """

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  def valid_integration_attributes(user, attrs \\ %{}) do
    Enum.into(attrs, %{
      user_id: user.id,
      provider: :github,
      access_token: "test_access_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh_token_#{System.unique_integer([:positive])}",
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
      granted_scopes: ["repo", "user:email"],
      provider_metadata: %{
        "provider_user_id" => "12345",
        "username" => "testuser",
        "avatar_url" => "https://example.com/avatar.png"
      }
    })
  end

  def valid_github_integration_attributes(user, attrs \\ %{}) do
    valid_integration_attributes(user, Map.merge(%{provider: :github}, attrs))
  end

  def valid_gitlab_integration_attributes(user, attrs \\ %{}) do
    valid_integration_attributes(user, Map.merge(%{provider: :gitlab}, attrs))
  end

  def valid_bitbucket_integration_attributes(user, attrs \\ %{}) do
    valid_integration_attributes(user, Map.merge(%{provider: :bitbucket}, attrs))
  end

  def expired_integration_attributes(user, attrs \\ %{}) do
    valid_integration_attributes(
      user,
      Map.merge(%{expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)}, attrs)
    )
  end

  def integration_without_refresh_token_attributes(user, attrs \\ %{}) do
    valid_integration_attributes(user, Map.merge(%{refresh_token: nil}, attrs))
  end

  def integration_fixture(user, attrs \\ %{}) do
    %Integration{}
    |> Integration.changeset(valid_integration_attributes(user, attrs))
    |> Repo.insert!()
  end

  def github_integration_fixture(user, attrs \\ %{}) do
    integration_fixture(user, Map.merge(%{provider: :github}, attrs))
  end

  def gitlab_integration_fixture(user, attrs \\ %{}) do
    integration_fixture(user, Map.merge(%{provider: :gitlab}, attrs))
  end

  def bitbucket_integration_fixture(user, attrs \\ %{}) do
    integration_fixture(user, Map.merge(%{provider: :bitbucket}, attrs))
  end

  def expired_integration_fixture(user, attrs \\ %{}) do
    integration_fixture(user, expired_integration_attributes(user, attrs))
  end

  def integration_without_refresh_token_fixture(user, attrs \\ %{}) do
    integration_fixture(user, integration_without_refresh_token_attributes(user, attrs))
  end
end
