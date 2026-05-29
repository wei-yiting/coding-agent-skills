---
name: frontend-test-writing
description: Best practices for writing React Testing Library (Vitest) unit/integration tests and Playwright E2E tests. Enforces the testing-library guiding principle (test what users see, not implementation details), web-first Playwright assertions, correct query priority, state-based UI coverage, and the correct layer split between RTL and E2E. Use this skill whenever writing, editing, reviewing, or auditing frontend tests — component tests, integration tests, E2E specs — planning test coverage, or debugging flaky tests. Also trigger when the user mentions React Testing Library, RTL, vitest, vi.mock, vi.spyOn, vi.hoisted, vi.useFakeTimers, fake timers, renderHook, testing hooks, custom hook tests, MSW, mock service worker, msw handlers, setupServer, server.use, jest-dom, Playwright, E2E, snapshot testing, getByTestId, getByRole, findByRole, waitFor, toHaveAttribute, toContainText, test selectors, test flakiness, fixtures, tags like @smoke/@critical, axe, jest-axe, a11y testing, accessibility testing, or asks what to test / what not to test in a frontend component.
---

# Frontend Test Writing

## Guiding Principle

> The more your tests resemble the way your software is used, the more confidence they can give you.

Every decision — query choice, assertion style, what to test vs skip — flows from this. Before writing any assertion, ask: "can a real user perceive this?" If no, it's an implementation detail and you're building a brittle test that will break during refactors while missing real regressions.

## Verify Library APIs Before Writing

When a task touches a specific API signature (jest-dom matchers, Playwright locator methods, Vitest `vi.*`, MSW handlers, testing-library options), verify with Context7 or the library's official docs before writing code. Matcher signatures and option names vary across versions, and cross-library confusion — e.g., `toHaveAttribute` accepts regex in Playwright but **not** in jest-dom — is the source of a whole class of silent test failures. This is a low-cost check; skip it only when you're already sure of the signature from recent first-hand use.

## The Two Layers

| Layer | Tool | What belongs here |
|---|---|---|
| **Unit / Integration** | Vitest + React Testing Library | Component render + state transitions + prop behavior + user-facing hooks. Most of your coverage lives here. |
| **E2E** | Playwright | Things only a real browser can verify: scroll, page reload, real streaming, security invariants enforced end-to-end, cross-tab state. |

**The cardinal rule**: Don't duplicate. If RTL can test it, E2E shouldn't. Every E2E test should assert something that would silently pass in jsdom but could break in a real browser. Duplicate coverage doubles CI time and doubles the blast radius of unrelated refactors.

See `references/layer-policy.md` for the decision flow and concrete examples of what to downshift from E2E to RTL.

## Coverage Strategy — Testing Trophy

```
         /  E2E  \        Few: real user journeys (login → checkout → confirmation)
        /─────────\
       / Integration\     Most confidence: components wired together under realistic state
      /─────────────\
     /     Unit      \    Selective: pure logic, utility functions, complex hooks
    /─────────────────\
   /      Static       \  Free: TypeScript + ESLint catch a huge class of bugs
  ───────────────────────
```

- **Don't write a test per component.** Write a test per user-observable behavior or user flow. A pure presentational `<Badge />` usually doesn't need its own test — TypeScript enforces prop shape, and integration tests cover real usage.
- **Don't chase 100% coverage.** Returns diminish sharply after ~70%. The last 30% is usually implementation detail or error paths that already can't happen.
- **Prioritize tests for**: (a) conditional rendering (loading / empty / error / success / disabled), (b) critical user flows, (c) regression tests pinned to real bug fixes.

See `references/state-based-testing.md` for how to decompose a component's states.

## Query Priority — Both Tools

Official priority (applies to both RTL and Playwright, with minor variations):

| Priority | RTL query | Playwright locator | When |
|---|---|---|---|
| 1. Semantic, accessibility-first | `getByRole('button', { name: /submit/i })` | `getByRole('button', { name: 'Submit' })` | First choice — tests what all users (including assistive tech) experience |
| 2. Form affordances | `getByLabelText('Email')`, `getByPlaceholderText`, `getByDisplayValue` | `getByLabel`, `getByPlaceholder` | Form inputs |
| 3. Visible text | `getByText(/ready/i)` | `getByText('Ready')` | Text content the user actually reads |
| 4. Images / media | `getByAltText`, `getByTitle` | `getByAltText`, `getByTitle` | Media |
| 5. Last resort | `getByTestId` | `getByTestId` | Only when no semantic option exists (icon-only buttons, purely visual elements). In Playwright, `data-testid` is slightly more tolerated per official docs. |

**Never use** `container.querySelector(...)` in RTL unless the thing you're checking has no user-perceivable correspondence (rare — usually for pure security invariants like "no anchor has `javascript:` href"). Never use `page.locator('.css-class-name')` in Playwright — CSS classes are implementation details.

## Existence vs Non-existence Assertions

| Intent | Pattern | Why |
|---|---|---|
| Element should exist | `expect(screen.getByRole(...)).toBeInTheDocument()` or just `screen.getByRole(...)` | `getBy*` throws a descriptive error listing available roles when it fails. `queryBy* + toBeInTheDocument` hides the real problem behind a vague assertion. |
| Element should NOT exist | `expect(screen.queryByRole(...)).not.toBeInTheDocument()` | `queryBy*` returns `null` instead of throwing. |
| Element arrives asynchronously | `await screen.findByRole(...)` | Better than `await waitFor(() => screen.getByRole(...))` — less nesting, clearer intent. |

## Async — Do Not Mix Side Effects and Assertions

```ts
// Wrong — side effect inside waitFor means it runs on every retry
await waitFor(() => {
  fireEvent.click(button);
  expect(something).toBeVisible();
});

// Right — side effect once, assertion auto-retries
await user.click(button);
await expect(screen.findByText(/success/)).toBeInTheDocument();
```

## The Three Queries You Will Misuse Most

1. **`getByTestId` when a semantic option exists** — 80% of `getByTestId` usage in reviewed code should have been `getByRole` + `name`. `testid` is a last resort, not a default.
2. **`getAttribute(...)` + `toContain(...)` in Playwright** — loses auto-retry. Use `toHaveAttribute(name, regex)` instead. (RTL's `toHaveAttribute` only accepts strings — see the quirks below.)
3. **`waitForTimeout(...)` in Playwright** — a hard wait is always wrong outside of debugging. Use a condition-based wait or a DOM contract attribute.

## Critical Tool Differences

RTL (jest-dom) and Playwright share vocabulary but differ in important ways. Mixing them up creates tests that silently don't work:

| API | jest-dom (RTL) | Playwright |
|---|---|---|
| `toHaveAttribute(name, value)` | Value must be a **string**, exact match | Value can be **string or regex**; auto-retries |
| `toHaveText(str)` | n/a (use `toHaveTextContent`) | Auto-retries |
| `toHaveClass(cls)` | Exists but discouraged as primary assertion | n/a |
| Simulating user events | `userEvent.type(el, 'hello')` | `page.getByRole('textbox').fill('hello')` |
| Waiting for async | `findByRole` / `waitFor` | web-first assertions auto-retry; `expect.poll` for arbitrary state |
| Matching against regex | `expect(el.getAttribute('rel')).toMatch(/noopener/)` | `expect(locator).toHaveAttribute('rel', /noopener/)` |

**Common trap**: assuming `toHaveAttribute(name, /regex/)` works in RTL. It doesn't. Either use an exact string or drop to `expect(el.getAttribute(name)).toMatch(regex)`.

## State-Based UI Testing

For any stateful component, the correct shape of a test suite is **one case per meaningful state**, with each case asserting what the user sees in that state.

```ts
// ToolCard has 5 visual states — test each explicitly
test('input-streaming renders running status dot', () => {
  render(<ToolCard part={{ ...base, state: 'input-streaming' }} isAborted={false} />);
  expect(screen.getByTestId('status-dot')).toHaveAttribute('data-status-state', 'running');
});

test('output-error renders friendly error title + error status dot', () => { ... });
test('aborted overrides running state', () => { ... });
// ... one case per state
```

**Do not use snapshot tests to "lock down" UI.** Snapshots fail in three situations — real regression, irrelevant DOM refactor, dependency upgrade — and the team quickly learns to blindly `-u` them instead of investigating. State-based assertions express intent per case, snapshots don't. See `references/rtl.md` for the snapshot testing section.

## Assert User-Visible Contracts, Not CSS Classes

```ts
// Wrong — CSS class is implementation detail, can rename without UX change
expect(dot.className).toMatch(/animate-pulse/);

// Right — data attribute is the component's declared test-facing contract
expect(dot).toHaveAttribute('data-status-state', 'running');
```

When a visual state is semantically meaningful, have the component expose it as a `data-*` attribute. Tests read the attribute; CSS reads the attribute too. This is Kent C. Dodds' recommended pattern for "things the tests need to know about that aren't expressible as ARIA."

Examples from real component design:
- `<MessageList data-status={status} data-at-bottom={bool}>` — lets E2E assert scroll anchoring without `page.evaluate`
- `<ToolCard data-tool-state={state} data-tool-call-id={id}>` — lets tests identify specific cards and their states
- `<ErrorBlock data-testid={source === 'pre-stream' ? 'stream-error-block' : 'inline-error-block'}>` — surfaces the variant

## Playwright E2E Specifics

### Web-first assertions — always

Playwright's `expect(locator).toXxx()` auto-polls until the condition is met or times out. Never unwrap a value first:

```ts
// Wrong — snapshot in time, no retry
const text = await loc.textContent();
expect(text).toBe('Done');

// Right — retries until true or timeout
await expect(loc).toHaveText('Done');
```

For state that isn't covered by a built-in assertion, use `expect.poll`:

```ts
await expect.poll(() => viewport.evaluate((el) => el.scrollTop)).toBe(0);
```

### Hard waits — never

```ts
await page.waitForTimeout(500);     // Wrong
await page.waitForLoadState('networkidle');  // Usually wrong — SPA background requests make this unpredictable
```

Replace with a condition on something the user can perceive: `await expect(locator).toHaveText(/.../)`, `await locator.waitFor({ state: 'visible' })`, or `await expect.poll(...)`.

### Conditional logic is a smell

```ts
// Wrong — if you don't know what's expected, the test doesn't know what to verify
const count = await mailAnchor.count();
if (count > 0) {
  expect(mailAnchor.getAttribute('href')).not.toMatch(/^javascript:/);
}

// Right — pick a side, document it, assert it
await expect(mailAnchor).toHaveAttribute('href', 'mailto:x@y.com');
```

If the actual behavior is genuinely nondeterministic, that's a product bug or a missing spec. Fix it, don't wrap the test in a conditional.

### Fixtures over repeated ceremony

If 10 specs all begin with `fill textarea → click send → wait for data-status=ready`, that ceremony belongs in a fixture. Keeps specs short, gives you one place to tune timeouts, and catches setup bugs once instead of N times.

```ts
// tests/e2e/fixtures.ts
export const test = base.extend<{ chat: ChatFixture }>({
  chat: async ({ page }, use) => {
    await use({
      gotoFixture: (name) => page.goto(`/?msw_fixture=${name}`),
      sendMessage: async (text) => { ... },
      waitReady: () => expect(page.getByTestId('message-list')).toHaveAttribute('data-status', 'ready'),
    });
  },
});
```

### Native tag API — use it

```ts
// Wrong — tag buried in a string, --grep is fragile, test title drifts with plan edits
test('J-regen-retry-01 @critical: regenerate failure → retry succeeds', async ({ page }) => { ... });

// Right — Playwright 1.42+ native API, --grep @critical works cleanly, reporter shows tags
test(
  'regenerate failure → retry succeeds',
  { tag: ['@critical', '@regression'] },
  async ({ chat, page }) => { ... },
);
```

Typical taxonomy:
- `@smoke` — deploy verification canary, ~5 tests, < 3 min
- `@critical` — P0 regression, ship-blocker
- `@security` — dedicated security invariants
- `@regression` — catch-all, every test carries this for nightly full runs

Document the taxonomy in `tests/e2e/TAGS.md`.

### playwright.config.ts — the non-negotiables

Four settings that make the difference between a debuggable and an opaque CI failure:

- `trace: 'on-first-retry'` — full action timeline + DOM snapshots on flake
- `video: 'retain-on-failure'` — visual context when something's wrong
- `screenshot: 'only-on-failure'` — low-cost failure evidence
- `retries: process.env.CI ? 2 : 0` — absorb genuine infra flake on CI, fail fast locally

Without trace/video/screenshot, a CI failure is undebuggable — the report is a failure message and nothing else. Ship these from day one.

See `references/playwright.md` for the full config, fullyParallel/forbidOnly/reporter/projects/webServer, MSW integration, preview-mode builds, cross-browser gotchas, and CI wiring.

## Common Anti-Patterns Quick Reference

| Anti-pattern | Fix |
|---|---|
| `const { getByRole } = render(...)` | Use `screen.getByRole(...)` |
| `getByTestId('submit-btn')` when there's a `<button>Submit</button>` | `getByRole('button', { name: /submit/i })` |
| `container.querySelector('.btn-primary')` | Refactor component to expose role/text/data-attr, then query semantically |
| `fireEvent.click(btn)` | `await userEvent.click(btn)` (fireEvent only for events userEvent can't express, like `isComposing`) |
| `await waitFor(() => screen.getByRole(...))` | `await screen.findByRole(...)` |
| `expect(queryByX).toBeInTheDocument()` | `expect(getByX).toBeInTheDocument()` or just `getByX(...)` |
| `expect(button.disabled).toBe(true)` | `expect(button).toBeDisabled()` |
| `expect(dot.className).toMatch(/animate-pulse/)` | Expose `data-*` attribute; assert the attribute |
| `toMatchSnapshot()` on rendered UI | State-based assertions per case |
| `page.waitForTimeout(500)` | Condition-based wait |
| `expect(await locator.textContent()).toBe(...)` | `await expect(locator).toHaveText(...)` |
| `if (count > 0) { expect(...) }` in Playwright | Pick the expected behavior, assert deterministically |
| Tags in test title (`"@smoke: foo"`) | Native `{ tag: ['@smoke'] }` |
| Repeated `fill/click/wait` ceremony across specs | Playwright fixture |
| No `trace`/`video`/`screenshot` in config | Add them — undebuggable CI otherwise |

## When You're Reviewing Existing Tests

Scan for each of the patterns in the table above. Also check:

1. **Does every `@critical` test pass locally on every browser in the matrix?** Cross-browser failures surface real bugs (MSW + Firefox service-worker reload is a real example — see `references/playwright.md`).
2. **Is every state in a stateful component covered by at least one assertion?** E.g., does `ToolCard` have tests for all 5 `ToolUIState` values?
3. **Are tests duplicating coverage between layers?** If an E2E spec asserts the same thing as a RTL test, the E2E spec is dead weight.
4. **Are test titles referring to internal IDs (J-xxx, S-xxx, TC-xxx)?** BDD artifact IDs drift as plans update — titles should describe user behavior.
5. **Are coverage gaps hiding in silence?** MSW fixtures that exist but have no corresponding spec are unverified error paths.

## Process

When adding tests to an existing codebase:
1. **Read the component + related tests first.** Understand what's already covered before adding.
2. **Before modifying an existing test, check what the old assertion was protecting.** Kent's "save feedback, not just corrections" principle: if an old assertion has been there through multiple commits, someone thought it mattered.
3. **Run format / lint / tsc / vitest / e2e before pushing.** Pre-push must mirror CI — if CI runs format:check, you run format:check. If CI runs playwright, you run playwright. A broken CI is a broken PR.
4. **After edits that touch markdown tables or long strings, re-run `prettier --write`.** Prettier re-aligns column widths when the longest row changes — easy to miss if you run format check before your last edit.

## References

- **`references/rtl.md`** — React Testing Library + jest-dom deep dive: query priority in detail, matcher quirks, snapshot verdict, common mistakes with examples.
- **`references/vitest.md`** — Vitest-specific: `vi.mock` hoisting + `vi.hoisted`, fake timers + `userEvent` trap, ESM vs CJS quirks, setup file pattern, reset vs restore.
- **`references/playwright.md`** — Playwright deep dive: web-first assertions, fixtures, native tag API, preview-mode builds, cross-browser gotchas, CI wiring.
- **`references/msw.md`** — MSW setup for Node and browser: handler structure, per-test `server.use` overrides, fixture-routed E2E, Firefox service-worker trap.
- **`references/hooks-testing.md`** — `renderHook` patterns: when to test standalone vs through-component, async state, context wrappers, cleanup verification.
- **`references/state-based-testing.md`** — How to decompose components into states and what to assert for each.
- **`references/layer-policy.md`** — Decision flow for where a given test belongs (RTL vs integration vs E2E) with concrete downshift examples.
- **`references/anti-patterns.md`** — Every anti-pattern above with a concrete before/after example drawn from real refactors.
