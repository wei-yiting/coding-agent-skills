# State-Based UI Testing — The Philosophy and the Workflow

UIs are simple at the surface but can have many internal states. The number of assertions needed per component scales with the number of meaningful states it can be in, not with the number of lines of JSX.

This reference shows how to identify states and write one focused assertion set per state.

## Why State-Based

A single test that renders a component and "checks that it works" tells you one thing: does the default state render? It doesn't tell you whether `loading`, `error`, `empty`, `disabled`, or `retry-available` render correctly.

Snapshot tests compound this problem — they check *all* rendered output for the default case, giving the illusion of coverage while leaving every other state untested.

State-based testing decomposes a component into its states, covers each, and expresses intent per case. When a state-specific regression happens, the failing test name tells you exactly what broke.

## The Decomposition Workflow

### Step 1: Enumerate the state space

Start from the component's props and internal `useState` to identify dimensions:

```
Composer:
  - status dimension: ready | submitted | streaming | error
  - text dimension: empty | whitespace-only | real content
  - interaction dimension: typing vs IME composing
```

Not every dimension product is meaningful — but each meaningful combination is a test case. For Composer:

| Status | Text | Expected UI |
|---|---|---|
| ready | empty | Send button disabled |
| ready | whitespace | Send button disabled |
| ready | content | Send button enabled |
| submitted | any | Stop button shown (send hidden) |
| streaming | any | Stop button shown |
| error | content | (Revisit — what's the contract here?) |
| + IME composing | any | Enter doesn't trigger sendMessage |

### Step 2: Identify the user-facing truth per state

For each case, what can the user observe?
- A button's presence / absence
- A button's enabled state
- Text content
- An attribute (`aria-expanded`, `data-status`)
- A distinct element (typing indicator, error block)

If you can't name what the user sees, the state isn't really distinct — collapse it with a neighbor.

### Step 3: Express each as a tiny test

```ts
describe('Composer — status × text', () => {
  test('ready + empty → send disabled', () => {
    render(<Composer status="ready" sendMessage={vi.fn()} stop={vi.fn()} />);
    expect(screen.getByTestId('composer-send-btn')).toBeDisabled();
  });

  test('ready + whitespace → send disabled', async () => {
    const user = userEvent.setup();
    render(<Composer status="ready" sendMessage={vi.fn()} stop={vi.fn()} />);
    await user.type(screen.getByTestId('composer-textarea'), '   ');
    expect(screen.getByTestId('composer-send-btn')).toBeDisabled();
  });

  test('ready + content → send enabled', async () => { ... });
  test('submitted → stop visible, send not visible', () => { ... });
});
```

Three properties of good state-based tests:

1. **One render per test.** No shared state between cases.
2. **Assertions focus on the observable difference that defines this state.** Don't re-assert things all cases share.
3. **The test name describes the state, not the behavior.** "ready + empty → send disabled" is more informative than "handles empty input correctly."

## Common State Dimensions

Different components recur with similar state shapes. Use these as a starting checklist:

### Async-loading component
- `idle`
- `loading`
- `success` (with data)
- `success` (empty / no results)
- `error` (recoverable)
- `error` (non-recoverable)

### Form component
- `pristine + invalid` (input hasn't been touched)
- `dirty + invalid`
- `dirty + valid`
- `submitting`
- `submit-success`
- `submit-error`

### Stateful widget with transitions (expandable, carousel, tabs)
- initial state
- each post-interaction state
- edge cases: keyboard vs pointer, focus management, prevented-default scenarios

### Streaming / real-time UI
- `disconnected`
- `connecting`
- `streaming` (with content)
- `streaming` (no content yet — typing indicator)
- `complete`
- `error` (mid-stream)
- `error` (pre-connection)
- `aborted` (user-initiated)

## When a State Depends on Multiple Props / State

Sometimes a visual state emerges from the intersection of two dimensions. E.g., a `ToolCard`:

```
visualState:
  isAborted=false, state="input-available"   → running (pulsing dot)
  isAborted=false, state="output-available"  → success (green dot)
  isAborted=false, state="output-error"      → error (red dot)
  isAborted=true,  state="input-available"   → aborted (gray dot)    ← override
  isAborted=true,  state="input-streaming"   → aborted               ← override
  isAborted=true,  state="output-available"  → success               ← NOT overridden (terminal)
  isAborted=true,  state="output-error"      → error                 ← NOT overridden (terminal)
```

Each row is a test case. The NOT-overridden rows are the invariants you'd miss if you only tested the override cases.

## `data-*` Attributes — The Test Contract

When a state is semantically meaningful, expose it as a `data-*` attribute. This gives:

1. **Tests** a stable way to assert the state:
   ```ts
   expect(card).toHaveAttribute('data-tool-state', 'aborted');
   ```
2. **CSS** a way to style based on the state:
   ```css
   [data-tool-state="aborted"] .status-dot { background: gray; }
   ```
3. **The component** a clearer intent statement than "apply these classes under these conditions":
   ```tsx
   <div data-tool-state={visualState}>
   ```

Once the `data-*` contract is in place, tests assert the state signal, not the specific CSS or rendering details. Refactoring the styling doesn't break the tests.

## Keep State Transition Tests at the Integration Layer

State-based tests cover **one state per test**. Don't test transitions here.

Transitions (A → B → C) belong in integration tests where you simulate the user's actual journey through states. For example, `ChatPanel.integration.test.tsx` is the right layer to test "send → streaming → ready" transitions. The ToolCard or Composer component tests stay focused on one-state-at-a-time.

Why: unit-level state tests should be fast and independent. Transition chains grow long and fragile; they're more useful at the integration layer where you can exercise the realistic state machine in one go.

## Anti-Patterns Specific to State-Based Testing

1. **One mega-test that renders all states in sequence.** Hard to read, hard to debug. Split.

2. **Reusing the same `render` across states via `rerender`.** Works, but each case should be independent unless you're explicitly testing a transition. Fresh renders make debugging easier.

3. **Asserting things that don't depend on the state.** If every test asserts "the Send button is present," it's not a state test — it's a rendering smoke test. Trim to the delta.

4. **Conflating visual state with business state.** "user is authenticated" isn't a visual state — it's a prop. "authentication check is pending" IS a visual state (loading spinner). Don't test auth logic in UI state tests; test the visual consequence.

5. **Missing the NOT-override cases.** If state X overrides state Y under condition Z, also test that state X doesn't override state W. Those negative tests catch real regressions.
