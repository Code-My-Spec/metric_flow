<!-- cms:task type="LiveViewTest" component="MetricFlowWeb.AiLive.Chat" -->

Generate LiveView tests for the following component.
The component doesn't exist yet.
You are to write the tests before we implement the module, TDD style.
Only write the tests defined in the Test Assertions section of the design.
If you want to write more cases, you must modify the design first.


Use Phoenix.LiveViewTest to mount the view via live/2, test handle_event callbacks,
and validate rendered HTML structure.

Tests should be grouped by describe blocks that match the function signature EXACTLY.
Any blocks that don't match the test assertions in the spec will be rejected and you'll have to redo them.

Project: Metric FLow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: Chat
Component Type: liveview
Component Description: AI chat interface for data exploration. Displays a list of the user's previous chat sessions in a sidebar panel and an active conversation area. Users can start new sessions, continue existing ones, and ask natural language questions about their metrics and correlations. The assistant response is streamed token-by-token so the user sees output in real time. Supports an optional `context_type` and `context_id` query parameter pair so other pages (e.g., a correlation result, a dashboard) can open the chat with a pre-populated context. When no session is selected and the user has no history, an empty state explains what AI chat can do. The message input is disabled while an assistant response is streaming. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug before mount.

Parent Context Design File: no parent design
Component Design File: .code_my_spec/spec/metric_flow_web/ai_live/chat.spec.md
Core Components: lib/metric_flow_web/components/core_components.ex

Similar Components (for test pattern inspiration):
No similar components provided

Test Rules:
Test the happy path first and thoroughly at the top of the file.
Continue to write tests in descending order of likelihood.
Avoid mocks wherever possible. Use real data and implementations.
Use recorders like ex_vcr to record actual system interactions where you can't use real data and implementations.
Mocks are appropriate to use at the boundary of the application, especially when they will heavily impact the performance of the test suite.
Identify application boundaries that need mocks, and write them if necessary.
Tests should be relatively fast. We don't want to slow the test suite down.
Write fixed, concrete assertions. 
Never use case, if or "or" in your test assertions.
Do not use try catch statements in tests.
Use fixtures wherever possible.
Delegate as much setup as possible.
Use ExUnit.CaptureLog to prevent shitting up the logs.

# Collaboration Guidelines
- **Challenge and question**: Don't immediately agree or proceed with requests that seem suboptimal, unclear, or potentially problematic
- **Push back constructively**: If a proposed approach has issues, suggest better alternatives with clear reasoning
- **Think critically**: Consider edge cases, performance implications, maintainability, and best practices before implementing
- **Seek clarification**: Ask follow-up questions when requirements are ambiguous or could be interpreted multiple ways
- **Propose improvements**: Suggest better patterns, more robust solutions, or cleaner implementations when appropriate
- **Be a thoughtful collaborator**: Act as a good teammate who helps improve the overall quality and direction of the project

You run in an environment where ast-grep is available; whenever a search requires syntax-aware or structural matching, default to ast-grep --lang elixir -p '<pattern>' (or set --lang appropriately) and avoid falling back to text-only tools like rg or grep unless I explicitly request a plain-text search.

Write the test file to test/metric_flow_web/live/ai_live/chat_test.exs.

Focus on:
- Reading the design files to understand the component architecture and parent context
- Reading lib/metric_flow_web/components/core_components.ex to understand what function components the LiveView uses
- Mounting the LiveView via live/2 and testing mount assigns
- Testing handle_event callbacks with render_click, render_submit, etc.
- Validating rendered HTML structure with has_element? and render assertions
- Creating reusable fixture functions for test data
- Following test and fixture organization patterns from the rules
- Only implementing the test assertions from the design file
