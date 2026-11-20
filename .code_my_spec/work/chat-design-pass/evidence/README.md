# Evidence — chat-design-pass

Browser screenshots at 390px and 1440px (before/after) are part of the
DESIGN.md design-pass checklist, but this coder session has no attached
browser and cannot start the dev server to capture them. The visual
changes are described in the commit and are verified by
`test/metric_flow_web/live/ai_live/chat_test.exs`:

- Hero heading "What can I help you with today?"
- Four suggestion cards (Business Performance, Customer Insights,
  Marketing Effectiveness, Financial Health) with the mockup prompts
- Composer placeholder
  "Ask about revenue, marketing, customer trends, cash flow, or anything else..."
- Clicking a suggestion card produces a user message and clears the hero
- One session list only (the sidebar's "Recent conversations")

The owner should capture the two widths on the seeded Anderson Retail Co.
client (`client@example.com`) before merging to close the
`Design-Pass:` audit.
