# Layer Policy — RTL vs Integration vs E2E

Duplicate coverage across layers is the most common mistake in multi-layer test suites. This reference gives a decision flow for where a given test belongs, with concrete downshift examples.

## The Decision Flow

```
Is the behavior observable only in a real browser?
├─ YES → E2E
│   (examples: real scroll, page reload, service worker, cross-tab,
│    streaming with real timing, security invariants enforced end-to-end)
└─ NO → Is the behavior spanning multiple components?
    ├─ YES → Integration (RTL with a page-level component, MSW for transport)
    │   (examples: user-flow retry → recovery, clear-session reset,
    │    citation parser output displayed in Sources block)
    └─ NO → Is there meaningful conditional rendering or state?
        ├─ YES → Component test (RTL unit)
        │   (examples: ToolCard per-state, ErrorBlock per-variant,
        │    Composer disabled logic, Markdown URL sanitization)
        └─ NO → Don't write a test
            (examples: pure presentational Badge, layout wrappers)
```

## What Belongs Where

### E2E (Playwright)

Reserve E2E for things a real browser does that jsdom can't:

- **Real scroll** — `scrollTop`, overflow, scroll anchoring. jsdom doesn't compute layout.
- **Page reload** — `page.reload()` re-runs the full app init. Tests fresh-mount invariants.
- **Service workers / MSW worker integration** — only real browsers have service workers.
- **Streaming over real HTTP transport** — AI SDK + SSE end-to-end behavior.
- **Security invariants enforced end-to-end** — "in a real browser, no `javascript:` URL triggers a dialog." jsdom can't fire real dialog events.
- **Cross-tab / cross-origin** — only a real browser.
- **Keyboard/pointer interactions at the browser level** — tab order, focus traps, escape handling (jsdom does a weak approximation).

**Do NOT** use E2E for:

- Component render / prop / state logic → unit
- Conditional rendering → unit
- State machine transitions → integration
- Markdown parsing, sanitization output → unit
- Tool state rendering per variant → unit
- Error classifier output per input → unit

### Integration Tests (RTL at page level, MSW for transport)

For multi-component user flows where the page's state machine matters:

- Retry flow: error → click retry → recovered state, no duplicate user message
- Clear session: messages present → click clear → empty state, new chat ID
- Regenerate: success response → click regenerate → new assistant message replaces old
- Tool abort during streaming: click stop → running tools move to `aborted`, completed tools preserved

These are the "does the page wire together correctly" tests. They're often the highest-value tests in the whole suite.

### Unit / Component Tests (RTL)

- A single component with conditional rendering (`ToolCard`, `ErrorBlock`, `EmptyState`)
- A single hook (`useFollowBottom`, `useToolProgress`)
- A single pure function (`toFriendlyError`, `classifyError`, `extractSources`)

## Concrete Downshift Examples

### Example 1: Citation rendering

**E2E spec we had**: "citations render as RefSup with Sources block, 2 source links visible" — asserted counts after streaming a fixture.

**Why it's a downshift candidate**: The behavior is pure component-level — `AssistantMessage` receives parts + citations and renders them. No browser-specific behavior. jsdom + RTL can verify this with a trivial render + assertion.

**Where it moved**: `AssistantMessage.test.tsx` already had `TC-comp-citation-01..06` covering 6 citation scenarios at unit level. The E2E was a duplicate.

**Decision**: Delete the E2E. Keep RTL.

### Example 2: Tool card output state

**E2E spec we had**: "tool output-available → tool card visible with data-tool-state" — asserted after a fixture streamed.

**Why it's a downshift**: `ToolCard` renders based on `part.state` + `isAborted`. Zero browser-specific behavior. `ToolCard.test.tsx` covers all 5 states individually.

**Decision**: Delete the E2E. Keep RTL.

### Example 3: Regenerate button visibility

**E2E spec we had**: "regenerate happy path → button appears → click → new response." 

**Why it's partial downshift**: The button visibility logic is covered by `AssistantMessage.test.tsx` (`isLast && status === 'ready' → visible`). The click → new response flow is covered by `ChatPanel.integration.test.tsx` with MSW.

**Decision**: Delete the E2E. Both sub-behaviors have stronger coverage at lower layers.

### Example 4: XSS sanitization detail

**E2E spec we had**: 2 tests with ~30 lines each asserting every aspect of inline + reference-style link sanitization (javascript: stripped, mailto preserved, rel attrs on https, no dialog fires).

**Why it's partial downshift**: Most of the assertions (javascript: stripped, mailto preserved, rel=noopener) are react-markdown/DOMPurify behavior — pure component concern. Only the end-to-end "in a real browser, no dialog fires when loading a hostile fixture" needs the actual browser.

**Decision**: Keep 2 minimal E2E specs (one per attack vector) asserting only the browser-level invariant (no javascript: anchor rendered, no dialog fires). Move the sanitization detail to `Markdown.test.tsx` as unit tests (javascript: URL has href stripped, mailto preserved as-is, safe https has rel/target, mixed-link handling).

### Example 5: Error recovery

**E2E spec we had**: 11 assertions in one test — error block visible, error title text, retry button visible, user-bubble count=1 before, retry click, error block gone, status=ready, user-bubble count still=1, assistant message visible.

**Why it's a trim**: The user-bubble count invariant (no duplication) is covered by `ChatPanel.integration.test.tsx`. The error-title text match is covered by `ErrorBlock.test.tsx`. The intermediate status transitions are covered by the integration hook tests. What E2E uniquely verifies is: can we actually drive the UI end-to-end through error → retry → recovery with real network transport?

**Decision**: Keep the E2E but trim to 3 core assertions: (1) error UI surfaces, (2) retry click triggers recovery, (3) stream completes with assistant message. Delete the 8 assertions that duplicate lower-layer coverage.

## The Verdict Table

| Behavior | RTL unit | RTL integration | E2E |
|---|---|---|---|
| Component renders with prop X | ✅ | | |
| State transition (loading → ready) | | ✅ | |
| User message count invariant | | ✅ | |
| Error classifier output | ✅ (pure fn) | | |
| Friendly error title for status 500 | ✅ | | |
| Error block renders correct testId for source | ✅ | | |
| Click Retry triggers re-send | | ✅ | |
| Real SSE streaming works | | | ✅ |
| Page reload produces fresh state | | | ✅ |
| Real scroll anchoring works | | | ✅ |
| Stop button actually aborts streaming | | ✅ (via AbortController mock) | ✅ (with real streaming) |
| XSS: javascript: URL sanitized in markdown | ✅ | | |
| XSS: no dialog fires in real browser | | | ✅ |
| Markdown renders mailto correctly | ✅ | | |
| ToolCard each state | ✅ | | |

## The Cross-Check You Should Do Before Merging

When a PR adds a test at layer X, ask:

1. Is the same behavior already asserted at a lower layer?
2. Would a refactor at layer X-1 break this test for no good reason?
3. Could the behavior be tested at a lower layer with less setup?

If "yes" to any of those, downshift. Your test is doing duplicate work.

Conversely, when a PR deletes a test, ask:

1. Is there coverage at another layer for this behavior?
2. If no, the deletion is a coverage regression — the PR needs to add a test elsewhere first.
