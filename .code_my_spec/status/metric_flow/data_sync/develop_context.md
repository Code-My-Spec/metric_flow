# Context Lifecycle: DataSync

You are orchestrating the full development lifecycle for this context.

## Lifecycle Phases

1. **Context Spec** - Define the bounded context architecture
2. **Component Specs** - Design each child component
3. **Design Review** - Validate architecture before implementation
4. **Implementation** - Tests + code per component in dependency order

## Current Phase: Implementation

Implement in dependency order:
- **Schemas** first (no dependencies)
- **Repositories** next (depend on schemas)
- **Services/Logic** (depend on repositories and schemas)
- **Context module** last (delegates to and coordinates all the above)

For each component: write tests first, then implement code. Verify tests pass before moving to the next component.

Components to implement:

- **Behaviour** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_behaviour_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_behaviour_code.md`
- **DataSync** (context)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_code.md`
- **FacebookAds** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_facebookads_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_facebookads_code.md`
- **GoogleAds** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_googleads_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_googleads_code.md`
- **GoogleAnalytics** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_googleanalytics_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_googleanalytics_code.md`
- **QuickBooks** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_quickbooks_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_dataproviders_quickbooks_code.md`
- **Scheduler** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_scheduler_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_scheduler_code.md`
- **SyncHistory** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_synchistory_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_synchistory_code.md`
- **SyncHistoryRepository** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_synchistoryrepository_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_synchistoryrepository_code.md`
- **SyncJob** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_syncjob_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_syncjob_code.md`
- **SyncJobRepository** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_syncjobrepository_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_syncjobrepository_code.md`
- **SyncWorker** (module)
  - [ ] Test: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_syncworker_test.md`
  - [ ] Code: `.code_my_spec/status/metric_flow/data_sync/metricflow_datasync_syncworker_code.md`

For each component, invoke the appropriate subagent with the prompt file:
- Test prompts: `@"CodeMySpec:test-writer (agent)"`
- Code prompts: `@"CodeMySpec:code-writer (agent)"`


## Subagent Usage

Invoke the appropriate subagent for each prompt file:

- For spec prompts: `@"CodeMySpec:spec-writer (agent)"`
- For design review prompts: `@"CodeMySpec:spec-writer (agent)"`
- For test prompts: `@"CodeMySpec:test-writer (agent)"`
- For code prompts: `@"CodeMySpec:code-writer (agent)"`

## Workflow

1. Complete all tasks listed above for the current phase
2. **Stop the session** — end your turn so the stop hook can validate your work
3. The stop hook will check your progress and provide instructions for the next phase
4. If the hook blocks the stop, follow its feedback and repeat from step 1

**Important:** You must stop after completing each phase. Do not attempt to
continue to the next phase on your own — the stop hook generates the prompt
files you need for each subsequent phase.
