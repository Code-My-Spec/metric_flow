# qa-empty@example.com not created by qa_seeds.exs

## Status

resolved

## Severity

medium

## Scope

qa

## Description

qa_seeds_450.exs  states in its summary output: "Empty-state user: qa-empty@example.com — Created by qa_seeds.exs — no additional seeding required." However,  qa_seeds.exs  does not create  qa-empty@example.com . This user either does not exist or was created outside of the normal seed flow. The brief for story 450 correctly uses  qa-member@example.com  for empty-state testing, but  qa-member@example.com  belongs to "QA Test Account" (the shared team account) and sees all 5 insights seeded for  qa@example.com . There is no isolated user account with zero insights available through the current seed infrastructure. qa_seeds_450.exs  should be updated to create and reference a properly isolated user with its own empty personal account, or  qa_seeds.exs  should be updated to create  qa-empty@example.com  with a confirmed account and no insights. The empty-state scenario (B9) could not be fully validated because of this gap.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`

## Resolution

Added qa-empty@example.com to qa_seeds.exs as an isolated user with its own personal account and no team membership. The user is created and confirmed in the standard seed flow alongside qa@example.com and qa-member@example.com. The summary output now lists all three users. Updated priv/repo/qa_seeds.exs. qa_seeds_450.exs already referenced qa-empty@example.com correctly — it now matches what qa_seeds.exs creates.
