#!/usr/bin/env bash
# start-qa.sh — Seed QA data for a QA session.
#
# Usage:
#   cd /path/to/metric_flow
#   ./.code_my_spec/qa/scripts/start-qa.sh
#
# What it does:
#   1. Runs qa_seeds.exs to create QA user + team account (idempotent)
#   2. Prints credentials and instructions
#
# After running, use vibium MCP tools to launch browser and log in.

set -euo pipefail

BASE_URL="${APP_URL:-http://localhost:4070}"
QA_EMAIL="qa@example.com"
QA_PASS="hello world!"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "============================================"
echo " MetricFlow QA Session Setup"
echo "============================================"
echo ""

# Step 1: Run seed data
echo "==> Running seed data..."
cd "$PROJECT_DIR"
mix run priv/repo/qa_seeds.exs
echo ""

# Summary
echo "============================================"
echo " QA Data Seeded"
echo "============================================"
echo ""
echo "Credentials:"
echo "  Email:    $QA_EMAIL"
echo "  Password: $QA_PASS"
echo ""
echo "URLs:"
echo "  App:      $BASE_URL"
echo "  Login:    $BASE_URL/users/log-in"
echo "  Mailbox:  $BASE_URL/dev/mailbox"
echo ""
echo "Next steps (via vibium MCP tools):"
echo "  1. mcp__vibium__browser_launch(headless: true)"
echo "  2. Follow auth workflow in .code_my_spec/qa/plan.md"
echo "============================================"
