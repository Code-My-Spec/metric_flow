defmodule MetricFlowTest.ProvidersFixtures do
  @moduledoc """
  Test helpers for OAuth provider data structures.
  """

  def github_assent_user_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "sub" => "12345678",
      "email" => "user@example.com",
      "name" => "Test User",
      "preferred_username" => "testuser",
      "picture" => "https://avatars.githubusercontent.com/u/12345678"
    })
  end

  def gitlab_assent_user_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "sub" => "87654321",
      "email" => "user@gitlab.com",
      "name" => "GitLab User",
      "preferred_username" => "gitlabuser",
      "picture" => "https://gitlab.com/uploads/-/system/user/avatar/87654321/avatar.png"
    })
  end

  def bitbucket_assent_user_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "sub" => "11223344",
      "email" => "user@bitbucket.org",
      "name" => "Bitbucket User",
      "preferred_username" => "bitbucketuser",
      "picture" => "https://bitbucket.org/account/bitbucketuser/avatar/32/"
    })
  end

  def github_oauth_token_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "access_token" => "gho_#{random_string(36)}",
      "token_type" => "bearer",
      "scope" => "user:email,repo,read:org"
    })
  end

  def gitlab_oauth_token_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "access_token" => "glpat-#{random_string(20)}",
      "refresh_token" => "glrt-#{random_string(20)}",
      "token_type" => "bearer",
      "expires_in" => 7200,
      "scope" => "read_user api read_repository"
    })
  end

  def bitbucket_oauth_token_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      "access_token" => "bb_#{random_string(32)}",
      "refresh_token" => "bb_refresh_#{random_string(32)}",
      "token_type" => "bearer",
      "expires_in" => 3600,
      "scope" => "account repository"
    })
  end

  def github_user_with_minimal_data_fixture do
    %{
      "sub" => "99999999"
    }
  end

  def github_user_without_email_fixture do
    %{
      "sub" => "55555555",
      "name" => "No Email User",
      "preferred_username" => "noemailuser",
      "picture" => "https://avatars.githubusercontent.com/u/55555555"
    }
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
