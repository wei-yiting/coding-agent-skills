# React Testing Library + Vitest + jest-dom — Deep Dive

This reference expands on the SKILL.md summary. Read it when designing a new RTL test suite, debugging a specific jest-dom matcher, or deciding whether a particular assertion is idiomatic.

## The Guiding Principles (testing-library.com)

Three core tenets from the official docs:

1. **Test DOM nodes, not component instances.** Never reach for `wrapper.instance()`, `wrapper.state()`, or private class methods. If a tester has to peek into internal state, refactors become test-breaking events even when the user-facing behavior is unchanged.
2. **Simulate user interactions as faithfully as possible.** Use `userEvent` — it fires the realistic sequence of events (`pointerdown`, `mousedown`, `focus`, `pointerup`, `mouseup`, `click`) that a real user triggers. `fireEvent` fires only one event and is reserved for cases where `userEvent` can't express the nuance (a notable example: setting `nativeEvent.isComposing` for IME input).
3. **API should be simple and flexible.** If you find yourself reaching for five chained matchers or assembling a custom query function, the problem is usually upstream — the component is probably exposing state in a non-testable way.

## Query Priority — Full Breakdown

### Tier 1: Accessible to Everyone

Queries that reflect what **all** users experience — sighted, screen reader, keyboard-only.

- **`getByRole(role, options)`** — first choice for any interactive element. `role` uses WAI-ARIA role names (`button`, `link`, `textbox`, `combobox`, `dialog`, `alert`, `heading`, `listitem`, etc.). The `name` option filters by accessible name (text content, `aria-label`, associated `<label>`).
  - `getByRole('button', { name: /submit/i })` — the idiomatic form
  - `getByRole('textbox', { name: 'Email' })` — for labeled inputs
  - `getByRole('heading', { level: 1, name: /welcome/i })` — heading level is a valid option

- **`getByLabelText(text)`** — for form inputs with an associated `<label>`. Preferred over `getByPlaceholderText` because placeholders are a weaker affordance (they disappear on focus, aren't announced by all screen readers).

- **`getByPlaceholderText(text)`** — acceptable fallback when no `<label>` exists, but prefer fixing the HTML.

- **`getByText(text)`** — for any user-visible text. Use a regex (`/submit/i`) for partial / case-insensitive matching. Useful for text that isn't inside an interactive element.

- **`getByDisplayValue(value)`** — for pre-filled inputs, selects, textareas. Finds by the current value, useful for form edit tests.

### Tier 2: Semantic Queries

Slightly weaker than Tier 1 because they rely on HTML attributes the user may not perceive directly but that assistive technologies use.

- **`getByAltText(text)`** — images. `alt` is a genuine user-facing contract (read by screen readers, shown on broken images), so this isn't just an implementation detail.
- **`getByTitle(text)`** — `title` attribute. Rarely the right choice because `title` is inconsistently surfaced across browsers.

### Tier 3: Test IDs

- **`getByTestId(id)`** — last resort. Use only when:
  - The element has no user-perceivable way to identify it (a purely decorative icon, a layout wrapper that happens to be important to test)
  - You need to scope a sub-region and there's no natural role for it (e.g., `<section data-testid="sources-block">` when "Sources" is a visual affordance rather than a landmark)
  - The test is about a data contract with the browser (e.g., anchor `id` for URL fragment jumps)

Every `data-testid` you add is a contract the component has to maintain. Keep them intentional and few.

### Variants: `getBy` / `queryBy` / `findBy` / `getAllBy` / ...

| Prefix | Sync/Async | Found | Not found |
|---|---|---|---|
| `getBy` | sync | returns element | **throws** (with helpful error) |
| `queryBy` | sync | returns element | returns `null` |
| `findBy` | async | returns `Promise<element>` (resolves when found) | rejects after timeout (default 1000ms) |
| `getAllBy` | sync | returns `element[]` | throws if empty |
| `queryAllBy` | sync | returns `element[]` | returns `[]` |
| `findAllBy` | async | resolves to `element[]` | rejects after timeout |

**When to use which:**

- **Existence**: `getBy` or `getAllBy`. The throw-on-miss gives better error messages than `expect(queryBy(...)).toBeInTheDocument()`.
- **Non-existence**: `queryBy` + `.not.toBeInTheDocument()`. `getBy` would throw before you could assert not-found.
- **Async arrival**: `findBy`. This combines `waitFor` + `getBy` into one call with a default 1000ms timeout. Prefer this over `await waitFor(() => screen.getByX(...))`.

## Common Matchers and Their Quirks (jest-dom)

### `toHaveAttribute` — **strings only**

```ts
expect(el).toHaveAttribute('href', 'https://example.com');   // exact string — OK
expect(el).toHaveAttribute('href');                          // just existence — OK
expect(el).toHaveAttribute('href', /example/);               // regex — BROKEN, doesn't match

// If you need regex, drop down:
expect(el.getAttribute('href')).toMatch(/example/);
```

This is a common trap because **Playwright's `toHaveAttribute` does accept regex**. Don't assume cross-library parity.

### `toHaveTextContent` vs `toHaveText`

- jest-dom has `toHaveTextContent` (matches substring by default; accepts regex)
- jest-dom does NOT have `toHaveText`
- Playwright has `toHaveText` (web-first, auto-retries, accepts regex)

### `toBeDisabled` / `toBeEnabled` / `toBeVisible` / etc.

Prefer the semantic matchers over attribute/style inspection:

```ts
expect(button).toBeDisabled();         // right
expect(button.disabled).toBe(true);    // wrong — skips jest-dom's checks for aria-disabled, inherited disabled, etc.
```

Same for `toBeVisible` (which checks CSS `display`, `visibility`, and `hidden` attribute).

### `toHaveClass` — use sparingly

Asserting CSS class names is almost always testing an implementation detail. The class name can change without affecting UX (common during refactors). Two legitimate uses:

1. **Asserting a class the user explicitly configures** (`<Button variant="primary" />` → `.btn-primary` is OK if the variant is the contract).
2. **Asserting a test-only state class** when `data-*` attribute is not feasible. Rare.

Prefer `data-state` attributes over CSS classes for state signaling.

## userEvent vs fireEvent

### Default: `userEvent`

```ts
const user = userEvent.setup();
await user.type(textarea, 'hello');
await user.click(button);
await user.keyboard('{Enter}');
```

`userEvent.setup()` gives you a fresh user instance per test (useful if you need `advanceTimers` or other config).

### When `fireEvent` is correct

- **Events userEvent can't express.** The canonical example is IME composition:

  ```ts
  // userEvent.keyboard can't set nativeEvent.isComposing
  fireEvent.keyDown(textarea, { key: 'Enter', isComposing: true });
  ```

- **`scroll` events** on a viewport — userEvent doesn't simulate these.
- **Synthetic events you've constructed manually** for edge-case testing.

When using fireEvent for a documented reason, add a one-line comment explaining why — reviewers will otherwise flag it as an anti-pattern.

## State-Based UI Testing

A stateful component should have **one test per meaningful state**. Each test:

1. Renders the component with props that force the target state.
2. Asserts what the user can perceive in that state.

```ts
describe('ToolCard visual states', () => {
  test('input-streaming → running status dot', () => {
    render(<ToolCard part={{ ...base, state: 'input-streaming' }} isAborted={false} />);
    expect(screen.getByTestId('status-dot')).toHaveAttribute('data-status-state', 'running');
  });

  test('output-available → success status dot', () => { ... });
  test('output-error → error status dot + friendly error text', () => { ... });
  test('aborted (via isAborted=true, running state) → aborted dot, no pulse', () => { ... });
  test('output-available NOT overridden by isAborted (terminal state preserved)', () => { ... });
});
```

Patterns that help:

- **Expose state as `data-*` attributes** on the rendered DOM. This lets both tests and CSS read the same signal.
- **Keep each case small and focused.** If a test has 6 assertions, you're probably conflating multiple states.
- **Cover each case independently.** State transitions are for integration tests; this layer asserts that given state X, the UI is Y.

See `state-based-testing.md` for the decomposition workflow.

## Snapshot Testing Verdict

**Do not use snapshots to lock down UI.** Kent C. Dodds wrote the canonical post on this ("Effective Snapshot Testing"). The short version:

Snapshots fail in three situations:
1. Real regression (what you want).
2. Irrelevant DOM structure change (false negative).
3. Dependency upgrade or CSS-in-JS output shift (false negative).

In practice, the second and third dominate, and the team quickly learns to `jest --updateSnapshot` reflexively instead of investigating. The snapshot becomes a rubber stamp.

**Where snapshots ARE good:**
- Babel/AST plugin output
- Error message formatting
- CSS-in-JS output verification in isolation
- Small, intent-expressing snapshots (a few lines, with a clear title)

**Always bad:** whole-component snapshots of rendered UI.

## Integration vs Unit — Where to Put Coverage

The Testing Trophy puts **integration** at the widest layer. For React:

- **Integration tests** render a page or feature with multiple components wired together, mocking only the transport (MSW) or the external I/O.
- **Unit tests** focus on pure logic — utility functions, complex hooks, reducers — where rendering a component would obscure what you're testing.

**Don't write a test per component.** A pure `<Badge variant="success">Complete</Badge>` doesn't need its own test — TypeScript enforces the prop shape, and integration tests cover real usage. Components worth dedicated tests:
- Those with conditional rendering (loading / empty / error / success / disabled)
- Those with internal state transitions
- Those reused across many contexts (worth pinning the contract)

## Common Mistakes Catalog

The full list from Kent C. Dodds' "Common Mistakes with React Testing Library" plus additions from our experience:

1. **Destructuring from `render(...)`** → use `screen.*`
2. **Using `getByTestId` when semantic query works** → use `getByRole`
3. **`container.querySelector`** → refactor component to expose role/text/data-attr
4. **Asserting `element.disabled` directly** → `toBeDisabled`
5. **`waitFor(() => getByX(...))`** → `findByX`
6. **`expect(queryByX).toBeInTheDocument()` for existence** → use `getByX` (throws with better error)
7. **Side effects inside `waitFor`** → side effect outside, expect inside
8. **Manual `act()` wrapping** → `render` and `fireEvent`/`userEvent` already act-wrap
9. **`fireEvent` where `userEvent` would work** — see the guidance above
10. **Asserting CSS class names as the primary contract** → expose `data-*` attribute
11. **Snapshot testing rendered UI** — see the verdict section
12. **Mock that makes the component trivial to test** — if you're mocking so aggressively that the test is testing the mock, the test is worthless
13. **Testing props passed to a mocked child** — tests implementation, not behavior. Test what the page renders given props to the parent
14. **Conflating multiple states per test** — one state per case

## Error Messages — Let Them Help You

When a query fails, read the full error. RTL prints the current DOM (prettified) and often lists available roles. This tells you:

- Which roles are actually exposed (vs what you assumed)
- Whether the element exists at all or with a different accessible name
- Whether async timing is off (the DOM snapshot is taken at the moment of failure)

If the DOM looks unexpected, the test is correct to fail — the component probably isn't rendering what you think it is.

## Sources

- [Testing Library — Guiding Principles](https://testing-library.com/docs/guiding-principles)
- [Testing Library — About Queries](https://testing-library.com/docs/queries/about)
- [Kent C. Dodds — Common Mistakes with React Testing Library](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)
- [Kent C. Dodds — Testing Implementation Details](https://kentcdodds.com/blog/testing-implementation-details)
- [Kent C. Dodds — Write Tests. Not Too Many. Mostly Integration.](https://kentcdodds.com/blog/write-tests)
- [Kent C. Dodds — Effective Snapshot Testing](https://kentcdodds.com/blog/effective-snapshot-testing)
