#!/bin/bash
# Code generation script — produced by CodeMySpec code_generation task
# Re-run on a fresh Phoenix project to reproduce this scaffold.

set -e

# Authentication — generates Users context, User schema, session management,
# login/registration LiveViews, and phx.gen.auth Scope pattern
mix phx.gen.auth Users User users

# Multi-tenant accounts — generates Accounts context, Account/AccountMember
# schemas, AccountRepository, Authorization module, and account management LiveViews
mix cms_gen.accounts

# OAuth integrations — generates Integrations context, Integration schema,
# IntegrationRepository, OAuthStateStore, Providers.Behaviour, and
# IntegrationOauthController
mix cms_gen.integrations

# Feedback widget — generates the in-app feedback widget component
mix cms_gen.feedback_widget

# Apply all migrations
mix ecto.migrate

# Integration providers — generate OAuth provider modules for each platform
# Note: These were hand-written for this project due to custom requirements
# (multiple Google providers, QuickBooks custom OAuth2 strategy), but can be
# scaffolded with:
#
# mix cms_gen.integration_provider Facebook facebook
# mix cms_gen.integration_provider Google google
# mix cms_gen.integration_provider "Google Ads" google_ads
# mix cms_gen.integration_provider "Google Analytics" google_analytics
# mix cms_gen.integration_provider "Google Business" google_business
# mix cms_gen.integration_provider "Google Search Console" google_search_console
# mix cms_gen.integration_provider QuickBooks quickbooks
# mix cms_gen.integration_provider CodeMySpec codemyspec

echo "Code generation complete. Run 'mix compile' to verify."
