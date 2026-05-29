# Vitest — Deep Dive

This reference covers Vitest-specific patterns that aren't obvious from RTL/jest-dom alone: module mocking, fake timers, spy semantics, and integration gotchas. Read this when writing a test that needs `vi.*` APIs or debugging a mocking issue that "should work" but doesn't.

## `vi.mock` — The Hoisting Model

`vi.mock(path, factory?)` is **hoisted to the top of the file, before imports run**. Two consequences people repeatedly trip over:

1. Anything captured from the enclosing scope in the factory will be `undefined` when the factory executes. Use `vi.hoisted` to pre-compute values the factory references:

   ```ts
   const mocks = vi.hoisted(() => ({
     fetchUser: vi.fn(),
   }));

   vi.mock('./api', () => ({
     fetchUser: mocks.fetchUser,
   }));
   ```

2. `vi.mock` calls at the top level are unconditional. For per-test behavior changes, call `.mockImplementation` / `.mockReturnValue` on the mocked export rather than trying to re-mock.

## Partial Mocks

When you want to mock one export and keep the rest real:

```ts
vi.mock('./utils', async (importOriginal) => {
  const actual = await importOriginal<typeof import('./utils')>();
  return {
    ...actual,
    formatCurrency: vi.fn(() => '$X.XX'),
  };
});
```

`importOriginal` is generic-typed so `actual` is completion-friendly. This is the idiomatic form — don't hand-copy exports, you'll miss one.

## `vi.spyOn` — When to Prefer It

Use `vi.spyOn(obj, 'method')` when:
- You want to **observe** calls without replacing behavior (the default spy forwards to the original).
- The target is already imported and in scope (no module replacement needed).
- You want automatic teardown per test when paired with `restoreMocks: true` in config.

Don't use `vi.spyOn` for ESM namespace imports — the namespace object is frozen and assignment throws. Use `vi.mock` instead.

## Fake Timers + `userEvent` — The Standard Trap

`@testing-library/user-event` uses real `setTimeout` internally for event sequencing. If you call `vi.useFakeTimers()` and then `userEvent.click()`, the test hangs because the user event is waiting for a timer that will never fire.

**Correct setup** when fake timers are needed:

```ts
beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

test('debounced input', async () => {
  const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
  render(<Search />);

  await user.type(screen.getByRole('textbox'), 'hello');
  vi.advanceTimersByTime(500);   // flush debounce

  expect(await screen.findByText(/results for hello/i)).toBeInTheDocument();
});
```

The `advanceTimers` option wires `userEvent`'s internal waits through your fake-timer controller so user events and timer-driven code cooperate.

## Module Mocking — ESM vs CJS

Vitest defaults to ESM. ESM quirks worth internalizing:

- **No `require()`** — use dynamic `await import(...)` if you need lazy loading in tests.
- **Namespace imports are frozen** — `import * as api from './api'; api.foo = vi.fn()` throws. Use `vi.mock`.
- **Default export shape** — a module with `export default class Foo {}` becomes `{ default: class Foo {} }` at the namespace level. When mocking, return `{ default: ... }`:

  ```ts
  vi.mock('./Foo', () => ({
    default: class MockedFoo { /* ... */ },
  }));
  ```

## Typical Setup File

```ts
// src/setupTests.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

afterEach(() => {
  cleanup();   // auto with @testing-library/react 15+; explicit for older versions
});
```

Register via `vitest.config.ts`:

```ts
export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/setupTests.ts'],
    globals: true,       // optional — skip describe/it imports
    clearMocks: true,    // reset call history per test
    restoreMocks: true,  // revert spies per test (only affects vi.spyOn)
  },
});
```

## Reset vs Restore — Pick the Right One

| Method | What it does |
|---|---|
| `vi.clearAllMocks()` | Clears call history; keeps implementation |
| `vi.resetAllMocks()` | Clears history + strips implementation (mocks return undefined) |
| `vi.restoreAllMocks()` | Restores spies to the original; clears mocks (only affects `vi.spyOn`) |

If your suite mixes `vi.mock` and `vi.spyOn`, combine `clearMocks: true` (history) with `restoreMocks: true` (spy revert). Without the restore, spies leak across tests and make failures look random.

## Testing Async Errors

`.toThrow()` works for sync errors. For async:

```ts
await expect(fetchUser('bad-id')).rejects.toThrow(/not found/i);
```

Not `.toThrow()` on an awaited value — that asserts the **returned value** threw, which it didn't.

## Snapshot Serializers for Unstable Values

For stable snapshots of objects containing timestamps, UUIDs, or absolute paths, register serializers in the setup file:

```ts
import { expect } from 'vitest';

expect.addSnapshotSerializer({
  serialize: () => '<ISO timestamp>',
  test: (val) => typeof val === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(val),
});
```

This scopes the substitution to the test runtime without touching production code.

## Running a Single Test Fast

```bash
pnpm exec vitest run path/to/file.test.ts -t 'name fragment'   # single test by title
pnpm exec vitest path/to/file.test.ts                          # watch mode, single file
```

`-t` matches against `describe`/`test` titles via substring. Use it during development to tighten the feedback loop.

## Common Pitfalls

1. **Factory closes over out-of-scope vars** — use `vi.hoisted`.
2. **Fake timers without `advanceTimers` option** — `userEvent` hangs silently. Always wire them together.
3. **Forgetting `vi.useRealTimers()` in `afterEach`** — later tests in the same file inherit fake timers and debug sessions become confusing.
4. **Mocking a class but forgetting `{ default: ... }`** — the import returns the factory object as the whole module, not as default.
5. **Spying on an ESM namespace** — mock the module instead.

## Sources

- [Vitest — Mocking](https://vitest.dev/guide/mocking.html)
- [Vitest — Fake Timers](https://vitest.dev/api/vi.html#vi-usefaketimers)
- [@testing-library/user-event — Options](https://testing-library.com/docs/user-event/options)
