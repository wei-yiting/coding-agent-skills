# Testing React Hooks — When and How

Custom hooks are units, but usually the cleanest test is through the component that uses them. This reference covers the decision (test the hook or the component?) and the mechanics when standalone testing wins.

## When to Test the Hook Standalone

Prefer standalone hook tests only when:

1. **The hook is genuinely reusable** across components and has non-trivial logic worth pinning independently (e.g., `useDebouncedValue`, `usePagination`, `useFollowBottom`).
2. **Exercising it through a component would require disproportionate scaffolding** — complex provider stacks, DOM layout jsdom can't simulate, etc.
3. **The hook's contract is its return shape**, not the rendered UI — e.g., a hook that returns `{ data, error, refetch }` where the component is a thin consumer.

Otherwise, test through the component. The component test doubles as an integration test and better reflects real usage.

**Bad sign**: a hook test that mocks five downstream hooks to isolate the one under test. You're testing the mock stack, not the hook.

## `renderHook` Basics

```ts
import { renderHook, act } from '@testing-library/react';

test('useCounter increments', () => {
  const { result } = renderHook(() => useCounter(0));

  expect(result.current.count).toBe(0);

  act(() => {
    result.current.increment();
  });
  expect(result.current.count).toBe(1);
});
```

Two rules to internalize:

- `result.current` is the **latest** returned value after re-renders. Never destructure it into a local once — the reference goes stale.
- `act()` wraps state updates outside rendering so React flushes them synchronously. Without it, you get "not wrapped in act" warnings and flaky assertions.

## Async State Updates

For effects that resolve asynchronously:

```ts
import { waitFor } from '@testing-library/react';

test('useUser fetches', async () => {
  const { result } = renderHook(() => useUser('42'));

  expect(result.current.loading).toBe(true);

  await waitFor(() => {
    expect(result.current.loading).toBe(false);
  });
  expect(result.current.user).toEqual({ id: '42', name: 'Ada' });
});
```

Don't mix side effects and assertions inside `waitFor`:

```ts
// Wrong — side effect runs on every retry
await waitFor(() => {
  act(() => result.current.refetch());
  expect(result.current.data).toBeDefined();
});

// Right — side effect once, waitFor only polls the assertion
await act(() => result.current.refetch());
await waitFor(() => expect(result.current.data).toBeDefined());
```

## Hooks That Need Context

Pass a wrapper:

```ts
const wrapper = ({ children }: { children: React.ReactNode }) => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider user={mockUser}>{children}</AuthProvider>
  </QueryClientProvider>
);

const { result } = renderHook(() => useFavoriteItems(), { wrapper });
```

Each test should get a **fresh** `queryClient` / provider state — otherwise tests bleed cached data and failures look random. Create the wrapper in a helper that returns a fresh client per call.

## Rerender with New Args

`renderHook` returns a `rerender` that re-invokes the hook with new props:

```ts
const { result, rerender } = renderHook(
  ({ query }) => useSearch(query),
  { initialProps: { query: 'a' } }
);

rerender({ query: 'ab' });
await waitFor(() => expect(result.current.results).toHaveLength(2));
```

Use this to test prop-change behavior: debouncing reset, stable reference checks, cleanup/re-fetch patterns.

## Cleanup on Unmount

React calls cleanup on unmount. Verify with `unmount`:

```ts
const { unmount } = renderHook(() => useWindowSize());
const removeSpy = vi.spyOn(window, 'removeEventListener');

unmount();
expect(removeSpy).toHaveBeenCalledWith('resize', expect.any(Function));
```

For timer-heavy hooks, pair with fake timers and assert that `unmount` cancels pending work (otherwise the hook leaks).

## Testing a Hook Through Its Component

For most application hooks (data fetching, controlled-input logic, conditional rendering drivers), this is the higher-leverage approach:

```ts
test('Search debounces input', async () => {
  vi.useFakeTimers();
  const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
  render(<Search />);   // Search uses useDebouncedValue internally

  await user.type(screen.getByRole('textbox'), 'hello');
  vi.advanceTimersByTime(500);

  expect(await screen.findByText(/results for hello/i)).toBeInTheDocument();
});
```

You're testing the observable effect of the hook (debounced search results) through the UI contract the user actually sees. If this passes, you know both the hook and its consumer behave correctly together. If it fails, the stack trace points at the component, but the debugger can walk into the hook.

## When Standalone Tests Are Clearly Right

- **Pure logic hooks** without DOM interaction: `useSortedTable`, `useCurrencyFormat`. These are really pure functions dressed as hooks — test them like pure functions.
- **State-machine contracts** where you want each transition pinned: `useStepper`, `useMultiStageForm`.
- **Library primitives** your team publishes internally: `useClipboard`, `useHotkeys`. The contract is the return shape, not any specific consumer's UI.

## Common Pitfalls

1. **Stale `result.current`** — destructuring kills the re-render signal. Always read through `result.current` at assertion time.
2. **Missing `act` on state updates** — produces warnings and flaky tests. Use the async form (`await act(async () => { ... })`) when the update involves a promise.
3. **Testing implementation via hook return shape** when the real contract is UI. If your assertion is `expect(result.current.isOpen).toBe(true)`, ask whether `expect(screen.getByRole('dialog')).toBeVisible()` on the consuming component is the higher-leverage version.
4. **Shared provider state across tests** — wrap in a `beforeEach` that creates a fresh provider tree, or move the fresh-client factory into the wrapper helper.

## Sources

- [React Testing Library — renderHook](https://testing-library.com/docs/react-testing-library/api#renderhook)
- [React — Reusing Logic with Custom Hooks](https://react.dev/learn/reusing-logic-with-custom-hooks)
