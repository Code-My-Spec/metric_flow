# invitations table migration was not applied to the dev database

## Severity

info

## Scope

qa

## Description

When running  mix run priv/repo/qa_seeds_429.exs  for the first time, the script failed with  ERROR 42P01 (undefined_table) relation "invitations" does not exist . The migration  20260307000001_create_invitations.exs  had not been applied. Running  mix ecto.migrate  resolved this. The  start-qa.sh  script or the seed documentation should include  mix ecto.migrate  as a prerequisite step to prevent this failure for fresh environments.

## Source

QA Story 429 — `.code_my_spec/qa/429/result.md`
