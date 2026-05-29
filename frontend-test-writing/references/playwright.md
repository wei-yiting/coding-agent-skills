# Playwright E2E — Deep Dive

This reference expands on the SKILL.md summary. Read it when configuring a new Playwright project, debugging flakes, or working on cross-browser or CI integration.

## Web-First Assertions — The Foundation

Playwright's `expect(locator).toXxx()` is the idiomatic way to assert state. It auto-polls until the assertion passes or a timeout is hit. Skipping this is the most common source of flake.

```ts
// Wrong — snapshot at a moment, no retry
const isVisible = await locator.isVisible();
expect(isVisible).toBe(true);

// Right — auto-retries until visible or timeout
await expect(locator).toBeVisible();
```

### The web-first matchers you'll use most

| Matcher | Purpose |
|---|---|
| `toBeVisible()` / `toBeHidden()` | Visibility |
| `toHaveText(str \| regex)` | Full text match |
| `toContainText(str \| regex)` | Substring / pattern match |
| `toHaveAttribute(name, value)` | Attribute match (value can be string OR regex — unlike jest-dom) |
| `toHaveCount(n)` | Number of matched elements |
| `toBeEnabled()` / `toBeDisabled()` | Interactive state |
| `toHaveClass(name \| regex)` | CSS class (use sparingly, same caveats as jest-dom) |
| `toHaveURL(pattern)` | Current page URL |

### `expect.poll` for arbitrary state

When nothing fits, `expect.poll(fn).toXxx(value)` polls the function and applies a normal `expect` matcher to its return:

```ts
await expect
  .poll(() => viewport.evaluate((el) => el.scrollTop))
  .toBe(0);

await expect.poll(() => fetch('/api/status').then(r => r.json())).toEqual({ ready: true });
```

Use this for DOM state that isn't covered by a built-in assertion. Prefer exposing the state as a `data-*` attribute and using `toHaveAttribute` where possible — polling is a fallback.

## Locator Strategy

Playwright's locator priority is the same as Testing Library's, with one relaxation: `getByTestId` is more tolerated in Playwright per the official docs, because Playwright tests run in a real browser where the full accessibility tree is evaluated by real browser engines — the tradeoffs are different.

```ts
page.getByRole('button', { name: 'Submit' })           // first choice
page.getByLabel('Email')                                // form inputs
page.getByPlaceholder('Your email')                     // fallback
page.getByText(/welcome/i)                              // visible text
page.getByTestId('composer-send-btn')                   // last resort (slightly more tolerated than RTL)
```

**Never use** raw CSS selectors for anything the user cares about:

```ts
page.locator('.btn-primary')                            // brittle
page.locator('[data-testid="x"]')                       // use getByTestId instead
page.$('...')                                           // legacy API, replaced by .locator()
```

### Scoping with `.filter()` and `.locator()`

```ts
// All rows containing "NVDA"
page.getByRole('row').filter({ hasText: 'NVDA' });

// Anchor inside a specific section
page.getByTestId('sources-block').getByRole('link');

// "Link that doesn't have text X"
page.getByRole('link').filter({ hasNotText: /skip/i });
```

These compose cleanly and keep locators semantic.

## Hard Waits Are Always Wrong

```ts
await page.waitForTimeout(500);                           // bad
await page.waitForLoadState('networkidle');               // usually bad — SPA background XHR makes this unpredictable
await page.waitForLoadState('domcontentloaded');          // OK as "hydration done" signal
```

### Condition-based alternatives by scenario

| Scenario | Correct wait |
|---|---|
| Element appears | `await expect(locator).toBeVisible()` |
| Text arrives | `await expect(locator).toHaveText(/.../)` or `toContainText(...)` |
| Status attribute changes | `await expect(locator).toHaveAttribute('data-status', 'ready')` |
| Arbitrary DOM state | `await expect.poll(() => viewport.evaluate(...)).toBe(...)` |
| Navigation finishes | `await page.waitForURL(/foo/)` |
| Specific response | `await page.waitForResponse(url => url.includes('/api/x'))` |

### The only times `waitForTimeout` is acceptable

- **Debugging only.** Temporary, never committed.
- **Intentional pause for human observation** (in `--headed` debugging sessions).

## Fixtures — Replacing Ceremony

If your specs look like this in 10 places:

```ts
await page.goto('/?msw_fixture=happy-text');
await page.getByTestId('composer-textarea').fill('hello');
await page.getByTestId('composer-send-btn').click();
await expect(page.getByTestId('message-list')).toHaveAttribute('data-status', 'ready', { timeout: 10000 });
```

Extract to a fixture:

```ts
// tests/e2e/fixtures.ts
import { test as base, expect, type Page } from '@playwright/test';

type ChatFixture = {
  gotoFixture: (name: string) => Promise<void>;
  sendMessage: (text: string) => Promise<void>;
  waitReady: () => Promise<void>;
};

export const test = base.extend<{ chat: ChatFixture }>({
  chat: async ({ page }: { page: Page }, use) => {
    // eslint-disable-next-line react-hooks/rules-of-hooks -- Playwright fixture API, `use` is the yielder
    await use({
      gotoFixture: (name) => page.goto(`/?msw_fixture=${name}`),
      sendMessage: async (text) => {
        await page.getByTestId('composer-textarea').fill(text);
        await page.getByTestId('composer-send-btn').click();
      },
      waitReady: () => expect(page.getByTestId('message-list'))
        .toHaveAttribute('data-status', 'ready', { timeout: 10_000 }),
    });
  },
});

export { expect } from '@playwright/test';
```

Then every spec imports from fixtures:

```ts
import { test, expect } from '../fixtures';

test('...', async ({ chat, page }) => {
  await chat.gotoFixture('happy-text');
  await chat.sendMessage('hi');
  await chat.waitReady();
  // assertions...
});
```

Benefits: one place to tune timeouts, one place to fix setup bugs, specs shorten to ~30% of their original length.

### The `use` callback — ESLint friction

The `use` parameter in fixtures triggers `react-hooks/rules-of-hooks`. Add a comment-scoped `eslint-disable-next-line` on the `await use(...)` line — this is the documented Playwright API, not a React hook.

## Native Tag API

Playwright 1.42+ added a native `{ tag: [...] }` parameter:

```ts
test(
  'regenerate failure → retry succeeds',
  { tag: ['@critical', '@regression'] },
  async ({ chat, page }) => { ... },
);
```

Why this over embedding tags in test titles:

- `--grep @critical` matches cleanly without title string assumptions
- HTML reporter and CLI output annotate tags visibly
- Tags survive test renames (titles change, tag metadata doesn't)
- Multiple tags per test (common: `@critical @regression`) read naturally

### Suggested taxonomy

| Tag | Intent | Budget |
|---|---|---|
| `@smoke` | Deploy-verification canary. Covers basic app operability. | < 3 min total, ~5 tests |
| `@critical` | P0 regression guard. Ship-blocker if fails. | 5-10 tests |
| `@security` | Dedicated security invariants (XSS, injection). | Few, tight |
| `@regression` | Catch-all. Every test carries this. Full-suite target for nightly. | All |

Document the taxonomy in `tests/e2e/TAGS.md` so the team doesn't re-argue the boundaries.

## `playwright.config.ts` — Production-Grade Minimum

```ts
import { defineConfig, devices } from '@playwright/test';

const isCI = !!process.env.CI;

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: isCI,                                       // PRs can't slip `.only`
  retries: isCI ? 2 : 0,                                  // retry flake on CI, fail fast locally
  workers: isCI ? 2 : undefined,                          // tune for runner cores
  reporter: isCI
    ? [['html', { open: 'never' }], ['list']]
    : [['list']],
  expect: { timeout: 5_000 },                             // global assertion timeout
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',                              // debuggable CI failures
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
  ],
  webServer: {
    command: 'pnpm run preview:e2e',                      // prod build, not dev
    url: 'http://localhost:5173',
    reuseExistingServer: !isCI,                           // CI spins fresh every time
    timeout: 120_000,
  },
});
```

### Why each piece matters

- **`trace: 'on-first-retry'` + `video` + `screenshot`** — without these, a CI failure is un-debuggable. You get a failure message and no context. Adding these is cheap (artifacts only on failure / retry) and saves hours.
- **`forbidOnly: isCI`** — prevents a merged PR from accidentally containing `test.only` that would skip the rest.
- **`retries: 2` on CI** — absorbs genuine flake (network, timing) without masking real regressions. Local `retries: 0` makes you notice new flakes immediately.
- **`fullyParallel: true`** — default should be parallel; tests must be independent anyway.
- **`preview:e2e` not `dev`** — testing production bundle catches tree-shaking, CSS minification, and import-resolution edge cases that dev server masks.

## preview vs dev — Testing the Real Bundle

`vite dev` serves uncompiled modules. `vite preview` serves the built bundle. For E2E fidelity you want the latter.

Two considerations when switching:

### 1. MSW gating

If the codebase gates MSW on `import.meta.env.MODE === 'development'`, preview (which runs in `production` mode) won't load MSW at all. Fix by introducing a dedicated `e2e` mode:

```json
// package.json
"preview:e2e": "vite build --mode e2e && vite preview"
```

```ts
// main.tsx
async function enableMocking() {
  const mode = import.meta.env.MODE;
  if (mode !== 'development' && mode !== 'e2e') return;
  if (!new URLSearchParams(location.search).has('msw_fixture')) return;
  // ... start MSW worker
}
```

This keeps MSW out of real production builds while enabling it for E2E.

### 2. Port difference

`vite preview` defaults to port 4173, `vite dev` to 5173. Align them:

```ts
// vite.config.ts
export default defineConfig({
  server: { port: 5173, strictPort: true },
  preview: { port: 5173, strictPort: true },
});
```

## DOM Contracts via `data-*` Attributes

Tests and CSS often want to key off component state. Expose that state via `data-*`:

```tsx
<div
  data-testid="message-list-viewport"
  data-at-bottom={shouldFollowBottom ? 'true' : 'false'}
  onScroll={handleScroll}
>
  {/* ... */}
</div>
```

Now tests can do:

```ts
await expect(viewport).toHaveAttribute('data-at-bottom', 'true');
```

Instead of:

```ts
// brittle, no auto-retry, requires page.evaluate
const atBottom = await viewport.evaluate(el =>
  el.scrollHeight - el.scrollTop - el.clientHeight < 100
);
expect(atBottom).toBe(true);
```

The attribute is the component's declared test-facing contract. Tests read it, CSS can read it (`[data-at-bottom="false"] .scroll-hint { display: block; }`), and refactors that move the scroll logic don't break the contract.

## Conditional Logic in Tests — Don't

```ts
// Anti-pattern
const count = await locator.count();
if (count > 0) {
  expect(await locator.first().getAttribute('href')).not.toMatch(/^javascript:/);
}
```

This tests nothing when `count === 0`, and the test comment usually reveals why: "either behavior is acceptable." That's a missing spec. Decide:

- Is the mailto link supposed to be preserved? → `await expect(mailAnchor).toHaveAttribute('href', 'mailto:x@y.com')`
- Is it supposed to be stripped? → `await expect(mailAnchor).toHaveCount(0)`

Then pick and assert deterministically. If you genuinely don't know, that's a product bug; don't paper over it.

## MSW Integration for Fixture-Routed E2E

When using MSW in the browser to stub API responses for E2E:

- **Route via URL query param**: `?msw_fixture=happy-text` selects which fixture's handlers get registered.
- **Read the fixture from `Referer` header** in the handler, not from `request.url` (the fetch inside the app won't carry the page's query string).
- **Don't rely on module-level state resetting between tests.** Playwright's `BrowserContext`-per-test isolation plus fresh `page.goto` usually gives you a fresh JS bundle, so `const m = new Map()` at module top is effectively fresh per test. But if that assumption doesn't hold (shared worker, reused context), export a reset function and call it from the fixture.
- **Firefox caveat**: `worker.start()` can hang on page reload when the service worker is already registered. Workarounds: add a render-fallback timeout in `main.tsx` so React mounts regardless, OR exclude specific reload-dependent specs from Firefox via `testIgnore` in the project config:

  ```ts
  projects: [
    { name: 'firefox', testIgnore: /critical\/refresh-invariant/ },
  ],
  ```

## CI Integration

```yaml
# .github/workflows/ci.yml
frontend-e2e:
  runs-on: ubuntu-latest
  needs: frontend                                          # gate on lint/tsc/build/unit first
  defaults:
    run:
      working-directory: frontend
  steps:
    - uses: actions/checkout@v4
    - uses: pnpm/action-setup@v4
    - uses: actions/setup-node@v4
      with:
        node-version-file: .nvmrc
        cache: pnpm

    - name: Install dependencies
      run: pnpm install --frozen-lockfile

    - name: Install Playwright browsers
      run: pnpm exec playwright install --with-deps chromium firefox

    - name: Run E2E tests
      run: pnpm run test:e2e

    - name: Upload Playwright report
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: playwright-report
        path: frontend/playwright-report/
        retention-days: 7

    - name: Upload failure artifacts (traces/videos/screenshots)
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: playwright-test-results
        path: frontend/test-results/
        retention-days: 7
```

### Why `needs: frontend`

Gate E2E on build/lint/unit passing. If the build fails, E2E would just fail with a build error anyway — wasted CI minutes.

### `--with-deps`

`playwright install --with-deps` pulls the system libraries (libnss, libasound, etc.) chromium needs. Without it, CI will fail with cryptic shared-library errors.

## Debugging Flakes

1. **Read the trace.** `trace: 'on-first-retry'` + `actions.upload-artifact` means every CI failure has a `.zip` you can open with `npx playwright show-trace trace.zip`. It shows every action, DOM snapshot, network request, console log.
2. **Check if the flake is a hard-wait anti-pattern.** Hard waits correlate with flake by definition — they pass when the machine is fast enough and fail when it isn't.
3. **Check for module state shared across tests.** See the MSW note above.
4. **Run locally with `--repeat-each=3` or `--repeat-each=5`** on the flake. If it fails some times, the flake is real. If it passes every time locally but fails on CI, the issue is CI-specific (different CPU, different Chrome version, different network).
5. **Look for race conditions between fixture setup and the first `page.goto`.** Service worker registration, especially, is async.

## Sources

- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Locators](https://playwright.dev/docs/locators)
- [Playwright Fixtures](https://playwright.dev/docs/test-fixtures)
- [Playwright Assertions](https://playwright.dev/docs/api/class-locatorassertions)
- [Playwright Test Tags (1.42+)](https://playwright.dev/docs/test-annotations#tag-tests)
- Community on `networkidle`: [ray.run — alternatives](https://ray.run/questions/what-are-some-recommended-methods-in-playwright-to-wait-for-page-readiness-instead-of-using-page-waitfor-networkidle)
