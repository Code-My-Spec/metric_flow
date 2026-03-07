<!-- cms:task type="ContextDesignReview" component="MetricFlow.Invitations" -->

# Context Design Review

Review the architecture of a Phoenix context and its child components.

## Project

**Project:** Metric FLow
**Description:** Metric flow is a multi-account reporting solution that aggregates metrics from multiple platforms, aggregates and correlates them to business goals.

## Context Being Reviewed

**Name:** Invitations
**Module:** MetricFlow.Invitations
**Type:** context
**Description:** Invitation flow for granting account access.

## Spec Files to Review

### Context Spec
.code_my_spec/spec/metric_flow/invitations.spec.md

### Child Component Specs
No child components to review.

## User Stories
No user stories have been associated with this context.



## Review Tasks

1. **Read All Spec Files**: Read the context spec and every child component spec. Do not skip any.

2. **Cross-check types against descriptions**: For every function, verify the @spec types make sense for what the component description says it does. A module described as doing numeric operations must use numeric types, not strings.

3. **Verify every function belongs**: Each function in a component must align with that component's stated purpose. Flag any function that doesn't belong (e.g. multiply/2 in an addition-only module).

4. **Check test assertions for contradictions**: Read each function's Test Assertions list. Flag any pair of assertions that contradict each other (e.g. same input producing different expected outputs).

5. **Validate dependencies exist**: Every module listed in a Dependencies section must correspond to a real component in this architecture. Cross-reference against the context spec's Components section.

6. **Check context delegates match child APIs**: The context spec's Delegates section should reference functions that actually exist in child component specs.

7. **Verify story coverage**: Each user story's acceptance criteria should map to at least one function across the specs.

8. **Fix Issues**: If you find ANY problems in steps 2-6, you MUST update the spec files directly before writing the review. Do not write a passing review with known issues.

9. **Write Review**: Document your findings using the format below. The Issues section is REQUIRED if you fixed anything.

## Review Document Format
# Design Review

Design review documents summarize architectural analysis of a Phoenix context
and its child components. Reviews validate consistency, integration, and
alignment with user stories. Keep reviews concise and actionable.


## Required Sections

### Overview

Format:
- Use H2 heading
- Brief paragraph (2-4 sentences)

Content:
- State what was reviewed (context name and component count)
- Summarize the overall assessment (sound/needs work)


### Architecture

Format:
- Use H2 heading
- Bullet list of findings

Content:
- Assess separation of concerns
- Validate component type usage (schema, repository, service patterns)
- Check dependency relationships
- Flag any architectural concerns


### Integration

Format:
- Use H2 heading
- Bullet list of integration points

Content:
- List how components connect
- Identify public APIs and delegation points
- Note any missing or problematic integration points


### Conclusion

Format:
- Use H2 heading
- Single paragraph

Content:
- State readiness for implementation (ready/blocked)
- List any remaining action items if blocked


## Optional Sections

### Stories

Format:
- Use H2 heading
- Bullet list mapping stories to components

Content:
- For each user story, confirm which components satisfy it
- Identify any gaps in coverage


### Issues

Format:
- Use H2 heading
- Bullet list or "None found"

Content:
- List any issues discovered during review
- For each issue, note if it was fixed and how



## Output

Write your review to: **.code_my_spec/spec/metric_flow/invitations/design_review.md**

The review should be concise - focus on findings, not repetition of what was reviewed.
