# Building MetricFlow: 40 Commits, 2 Months, and a Machine That Wrote It All

## What is MetricFlow?

MetricFlow is a marketing analytics platform built in Elixir and Phoenix LiveView. Its purpose is deceptively simple: connect a business's ad spend on Google Ads, Facebook Ads, and Google Analytics to its revenue in QuickBooks, then surface the correlations that tell you which dollars are actually working. The product vision is a unified dashboard where marketers can stop guessing and start seeing which campaigns drive real income -- not just clicks.

What makes MetricFlow unusual is not the idea. Plenty of tools promise to correlate spend with revenue. What makes it unusual is how it was built: 40 commits across roughly two months, from January 30 to March 20, 2026, with Claude Code as the primary development partner. A human developer defined the specifications, made architectural calls, and steered the ship. The machines wrote the code, the tests, and the documentation. This narrative itself was written by a machine, looking back at what the machines built.

This is the story of that build.

## Phase 1: One Evening, 7,400 Lines (January 30)

MetricFlow was born in a single evening session. Three commits on the last night of January 2026 established everything a Phoenix application needs to exist: the project scaffold with DaisyUI theming and Heroicons, a full authentication system via `phx.gen.auth`, and documentation linked as a git submodule.

The speed was not reckless. The `Scope` pattern -- Phoenix's mechanism for carrying tenant and user context through every request -- was introduced in the very first auth commit, signaling that multi-tenancy was a day-one architectural concern, not an afterthought. Twenty-nine files and 3,300 lines of auth code landed with a comprehensive test suite attached.

Three commits. One evening. A working, authenticated, styled application with a test suite. The tone was set: move fast, but move correctly.

## Phase 2: The Blueprint Before the Building (February 22-23)

February's contribution was compressed into two extraordinary days. If January was pouring the foundation, February was simultaneously drafting the architectural blueprints and erecting the entire structural frame.

The first day was infrastructure. Oban arrived for background job processing. Cloak and Vault were wired in for encryption at rest. PromEx was configured for observability. And critically, the CodeMySpec framework and BDD spex testing harness were integrated. This last piece deserves emphasis: the project committed to specification-driven development before the first domain module existed. Every feature would begin as a written spec, proceed through failing tests, and arrive at working code. The methodology was not bolted on later. It was load-bearing from the start.

The second day was a tour de force. Over 25,000 lines of architecture documentation landed first -- not boilerplate README content, but detailed design decisions covering authorization strategy, the correlation engine, data provider API contracts, deployment topology, and LLM integration patterns. Rules were codified for every component type: how contexts should behave, how repositories should be structured, how schemas should be defined, how LiveView components should be organized. The blueprint was complete before the first domain module was written.

Then the domain itself materialized in a single sweeping commit. Four core contexts arrived fully formed:

- **Accounts** with multi-tenant membership and role-based authorization
- **Integrations** with a provider behaviour pattern and Google OAuth
- **Metrics** with a normalized repository for cross-platform data storage
- **DataSync** with a complete pipeline of sync jobs, workers, schedulers, and data providers for Google Ads, Google Analytics, Facebook Ads, and QuickBooks

Six database migrations. A full LiveView layer for account settings, integration flows, and onboarding. And then nearly 22,000 lines of test code: unit tests for every context, repository, and schema, plus over fifty BDD spex covering user stories from registration through OAuth integration.

Two days. A fully specified, implemented, and tested domain core. The architectural decision to write specs before code -- and to enforce module boundaries with the Boundary library from the start -- would pay dividends throughout March, when the pace of feature development accelerated dramatically.

## Phase 3: Integration Hardening and the Google Split (Early-Mid March)

March opened with the unglamorous but essential work of making integrations actually work. A proper home page replaced the default Phoenix landing. The invitation system shipped end-to-end: schemas, email notifiers, acceptance flows, and BDD specs. OAuth flows for Google, Facebook, and QuickBooks were debugged, then hardened with cassette-based HTTP replay tests that made the test suite deterministic against external APIs. Token revocation on disconnect was added. Twenty-nine test failures were hunted down and eliminated in a single commit.

Then came the most significant architectural pivot of the project. Google's original monolithic OAuth provider was split into three separate modules: Google Ads, Google Analytics, and Google Search Console. Each got its own integration record, its own provider logic, and its own OAuth flow. Google Search Console sync was implemented from scratch. Account pickers appeared for every provider, letting users select which ad accounts or analytics properties to sync.

This was not a refactor for cleanliness. It was a structural necessity. Google's APIs are not one API -- they are a family of APIs with different scopes, different data models, and different rate limits. Treating them as a single provider had been creating friction in the OAuth flows and confusion in the data model. The split resolved both problems and established a pattern: each data source gets its own first-class integration, regardless of whether the underlying vendor is the same.

QuickBooks OAuth proved particularly stubborn. The provider was completely rewritten to support daily credit/debit sync with proper test recording. The data backfill window was expanded to 548 days -- eighteen months of historical data, enough to capture seasonal patterns that shorter windows would miss.

## Phase 4: The Dashboard Revolution and AI Integration (March 18-20)

The final phase was the most visible. On March 18, the dashboard underwent a dramatic redesign. The old single-metric view -- functional but flat -- gave way to a multi-series Vega-Lite chart with a companion data table and date range controls. A QueryBuilder module was introduced to feed the chart engine structured data, and a ReportGenerator arrived alongside it: an AI-driven tool that could draft Vega-Lite visualization specs from natural language descriptions.

The implications of this architecture are worth pausing on. Rather than building a fixed set of chart types with hard-coded data bindings, MetricFlow chose to adopt Vega-Lite as its visualization grammar. This means the system can express any chart Vega-Lite can render -- line, bar, area, scatter, donut, layered composites -- through a declarative JSON spec. And because those specs are just data, an LLM can generate them. A user asks "show me Facebook spend versus QuickBooks revenue over the last 90 days," and the system can translate that into a working chart without any new frontend code.

Correlation analysis gained a goals configuration page, mode toggling between raw statistical output and an AI-assisted "SmartAI" view, and platform filtering. The AI chat feature shipped -- a conversational interface where users can ask questions like "why did my revenue drop last week?" and receive answers grounded in actual metric and correlation data.

The final days were consumed by QA. An automated QA agent ran against more than 25 user stories, producing detailed result files and hundreds of screenshots. Each failed run triggered targeted fixes: invitation token invalidation, nil account guards, dashboard button wiring, OAuth callback error handling, navigation bugs. The feedback loop was tight -- the QA agent found a problem, the development agent fixed it, and the QA agent verified the fix, often within the same session.

The last commits of the project addressed the multi-tenant agency model: agency-to-account linking and white-label originator auto-apply. These features are the first steps toward MetricFlow's commercial architecture, where agencies manage multiple client accounts under their own branding.

## The Human-AI Collaboration Model

MetricFlow was not built by a human who happened to use AI for autocomplete. It was built through a deliberate collaboration model where the human defined specifications and made architectural decisions, and Claude Code -- Anthropic's AI coding agent -- wrote the implementation, the tests, and the documentation.

The CodeMySpec methodology made this work. Specifications were written as structured documents with acceptance criteria. Architecture rules were codified in machine-readable formats. The Boundary library enforced dependency rules at compile time, catching violations that might otherwise require human code review to spot. BDD spex provided an executable contract between what the spec said and what the code did.

This is not a story about AI replacing developers. It is a story about a developer who found a way to operate at a pace that would be physically impossible alone -- 40 commits, tens of thousands of lines of tested code, across dozens of integrated subsystems -- by delegating implementation to a machine while retaining control of design. The specifications were the interface between human intent and machine output.

## Where It Stands

As of March 20, 2026, MetricFlow has a working authentication system with multi-tenant accounts, OAuth integrations with five data providers (Google Ads, Google Analytics, Google Search Console, Facebook Ads, and QuickBooks), a data sync pipeline with 548-day backfill, a Vega-Lite dashboard with AI-generated visualizations, correlation analysis with raw and AI-assisted modes, an AI chat interface for data exploration, and the beginnings of an agency white-label model.

The project has passed automated QA across more than 25 user stories. The test suite includes unit tests, integration tests, and BDD acceptance specs with cassette-recorded HTTP interactions.

What remains is the work of turning a functional platform into a production product: hardening the sync pipelines against real-world API failures, building out the agency billing model, expanding the correlation engine's statistical methods, and polishing the UI for users who are not the person who built it.

The trajectory is clear. The compounding that began in March -- where each new feature leveraged three features built the week before -- is accelerating. The specification-first methodology means new stories can be picked up and implemented with minimal context-switching. The architecture, enforced by Boundary and documented by CodeMySpec, remains navigable even as the codebase grows.

MetricFlow is two months old, built almost entirely by machines guided by human specifications. It is not finished. But it is real, it is tested, and it works. The machines are ready for the next commit.

---

*This narrative was generated by Claude Code (Opus 4.6), the same AI that helped build the codebase it describes. The monthly summaries it synthesizes were also machine-generated. The specifications that drove the code were human-authored. The architecture was a conversation between both.*
