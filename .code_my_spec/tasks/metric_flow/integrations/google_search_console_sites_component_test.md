Generate tests and fixtures for the following Phoenix component.
The component implementation already exists.
Write tests that validate the existing implementation against the design specification.


Tests should be grouped by describe blocks that match the function signature EXACTLY.
Any blocks that don't match the test assertions in the spec will be rejected and you'll have to redo them.

describe "get_test_assertions/1" do
  test "extracts test names from test blocks", %{tmp_dir: tmp_dir} do
    ...test code
  end
end

Project: Metric Flow
Project Description: Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.
Component Name: GoogleSearchConsoleSites
Component Type: module

Parent Context Design File: no parent design
Component Design File: .code_my_spec/spec/metric_flow/integrations/google_search_console_sites.spec.md

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

Write the test file to test/metric_flow/integrations/google_search_console_sites_test.exs.

Focus on:
- Reading the design files to understand the component architecture and parent context
- Creating reusable fixture functions for test data
- Testing all public API functions
- Testing edge cases and error conditions
- Testing with valid and invalid data
- Following test and fixture organization patterns from the rules
- Only implementing the test assertions from the design file
