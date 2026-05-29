# Anti-Patterns — Before and After

A catalog of real anti-patterns encountered during test audits, each with a concrete before / after.

## RTL / jest-dom

### 1. `container.querySelector` in place of a semantic query

```ts
// Before
const { container } = render(<Markdown text="See [3](https://blog.example.com/top-10)" ... />);
const anchors = container.querySelectorAll('a');
const inlineAnchor = Array.from(anchors).find(a => a.getAttribute('href') === 'https://blog.example.com/top-10');
expect(inlineAnchor).toBeDefined();
expect(inlineAnchor?.textContent).toBe('3');
expect(inlineAnchor?.getAttribute('target')).toBe('_blank');

// After
render(<Markdown text="See [3](https://blog.example.com/top-10)" ... />);
const inlineAnchor = screen.getByRole('link', { name: '3' });
expect(inlineAnchor).toHaveAttribute('href', 'https://blog.example.com/top-10');
expect(inlineAnchor).toHaveAttribute('target', '_blank');
```

**Why**: The before version (a) bypasses accessibility, (b) relies on DOM structure, (c) is verbose. The after version is a single semantic query.

### 2. Asserting CSS class name as the primary state signal

```ts
// Before
const dot = screen.getByTestId('status-dot');
expect(dot.className).toMatch(/animate-pulse/);

// After
const dot = screen.getByTestId('status-dot');
expect(dot).toHaveAttribute('data-status-state', 'running');
```

**Why**: `animate-pulse` is a Tailwind utility class — it could be renamed, split across classes, or replaced with a different animation without UX change. `data-status-state="running"` is the component's declared state contract.

### 3. Vacuously true assertions

```ts
// Before
const onSend = vi.fn();
render(<EmptyState onPickPrompt={onPickPrompt} />);  // onSend never passed
// ...
expect(onSend).not.toHaveBeenCalled();   // always true since onSend isn't wired

// After
// Delete the mock + assertion entirely. The intent (no auto-send) is captured
// by asserting onPickPrompt gets the chip text — not that some unrelated mock
// wasn't called.
expect(onPickPrompt).toHaveBeenCalledWith(expect.any(String));
```

**Why**: Vacuously-true assertions pass regardless of behavior. They create false confidence. If they're testing an invariant worth checking, they must actually exercise the code path.

### 4. `waitFor + getBy` instead of `findBy`

```ts
// Before
await waitFor(() => screen.getByRole('button', { name: /submit/i }));

// After
await screen.findByRole('button', { name: /submit/i });
```

**Why**: `findBy` is the combination of `waitFor + getBy` in a single idiomatic call. Less nesting, clearer intent, better error messages.

### 5. `fireEvent` where `userEvent` would work

```ts
// Before
fireEvent.change(input, { target: { value: 'hello' } });

// After
const user = userEvent.setup();
await user.type(input, 'hello');
```

**Why**: `fireEvent.change` fires one event. A real user types character by character — `userEvent.type` dispatches `keyDown`, `keyPress`, `input`, `keyUp` for each character. Some components subscribe to intermediate events. Tests that pass with fireEvent but fail with real users are silent failures.

### 6. Assuming `toHaveAttribute` takes a regex in jest-dom

```ts
// Before — looks correct if you've just used Playwright, but doesn't match
expect(anchor).toHaveAttribute('rel', /noopener/);
// Error: Expected rel=/noopener/ but got rel="noopener noreferrer"
//         (jest-dom compares the string form)

// After — two options
expect(anchor).toHaveAttribute('rel', 'noopener noreferrer');         // exact string
expect(anchor.getAttribute('rel')).toMatch(/noopener/);                // regex match
```

**Why**: jest-dom's `toHaveAttribute(name, value)` treats `value` as a string. Playwright's accepts a regex. This is the most common cross-tool trap.

### 7. `getByRole('link', ...)` when the anchor has no valid href

```ts
// Before
const text = 'Visit [bad site](javascript:alert(1)) now.';
render(<Markdown text={text} ... />);
const anchor = screen.getByRole('link', { name: 'bad site' });
// Error: no accessible link with that name

// After — after sanitization, href becomes empty, so the link role is dropped.
// Locate by text and walk up to the anchor.
render(<Markdown text={text} ... />);
const anchor = screen.getByText('bad site').closest('a');
expect(anchor!.getAttribute('href') ?? '').not.toMatch(/^javascript:/i);
```

**Why**: An anchor with empty `href` isn't exposed as a `link` role. When your test is specifically about sanitization (the href was stripped), you need to find the element another way.

## Playwright

### 8. Hard wait with `waitForTimeout`

```ts
// Before
await expect(page.getByTestId('assistant-message')).toBeVisible();
await page.waitForTimeout(500);  // "let some text stream in"
await page.getByTestId('composer-stop-btn').click();

// After — wait for a specific observable signal
await expect(page.getByTestId('assistant-message')).toBeVisible();
await expect(page.getByTestId('assistant-message')).toContainText('Paragraph 0.', { timeout: 10_000 });
await page.getByTestId('composer-stop-btn').click();
```

**Why**: The 500ms is arbitrary — it passes when the machine is fast and fails when it isn't. Waiting for observable content is deterministic.

### 9. `page.evaluate` + raw `expect` instead of web-first assertion

```ts
// Before
const isAtBottom = await viewport.evaluate(el =>
  el.scrollHeight - el.scrollTop - el.clientHeight < 100
);
expect(isAtBottom).toBe(true);

// After (requires component to expose `data-at-bottom` attribute)
await expect(viewport).toHaveAttribute('data-at-bottom', 'true');
```

**Why**: The before version is a snapshot — if the scroll hasn't completed when `evaluate` runs, the assertion fails. `toHaveAttribute` auto-polls until the condition is true or times out. Adding the `data-at-bottom` attribute is a one-line component change with permanent benefit.

### 10. `getAttribute + expect` instead of `toHaveAttribute`

```ts
// Before
const chatIdBefore = await page.getByTestId('chat-panel').getAttribute('data-chat-id');
// ...
const chatIdAfter = await page.getByTestId('chat-panel').getAttribute('data-chat-id');
expect(chatIdAfter).not.toBe(chatIdBefore);

// After
const chatPanel = page.getByTestId('chat-panel');
const chatIdBefore = await chatPanel.getAttribute('data-chat-id');
// ... trigger the reset
await expect.poll(() => chatPanel.getAttribute('data-chat-id')).not.toBe(chatIdBefore);
```

**Why**: `expect.poll` retries until the attribute changes or times out. The bare comparison is a snapshot.

### 11. Conditional assertions for "uncertain behavior"

```ts
// Before
const mailCount = await mailAnchor.count();
if (mailCount > 0) {
  const href = await mailAnchor.getAttribute('href');
  expect(href ?? '').not.toMatch(/^javascript:/);
}
// Comment: "either rendered as mailto or stripped — both acceptable"

// After — pick one and assert it
await expect(mailAnchor).toHaveAttribute('href', 'mailto:x@y.com');
```

**Why**: "Either is acceptable" is a missing spec. Research the library's actual behavior, pick the correct expectation, and assert deterministically. If the behavior is genuinely nondeterministic, that's a product bug.

### 12. Tags in test title strings

```ts
// Before
test('J-err-01 @critical: pre-stream error recovery via Retry', async ({ page }) => { ... });

// After
test(
  'pre-stream error recovery via Retry',
  { tag: ['@critical', '@regression'] },
  async ({ chat, page }) => { ... },
);
```

**Why**: Playwright 1.42+ native `{ tag: [...] }` API. `--grep @critical` matches cleanly. BDD artifact IDs (J-xxx) drift as plans update and shouldn't be in test titles.

### 13. Repeated setup ceremony across specs

Search your E2E directory for `fill.*composer-textarea.*send.*click`. Every occurrence is a place where a fixture would save code.

```ts
// Before — in 10 specs
await page.goto('/?msw_fixture=happy-text');
await page.getByTestId('composer-textarea').fill('hello');
await page.getByTestId('composer-send-btn').click();
await expect(page.getByTestId('message-list')).toHaveAttribute('data-status', 'ready', { timeout: 10000 });

// After — once in fixtures.ts, then in every spec:
await chat.gotoFixture('happy-text');
await chat.sendMessage('hello');
await chat.waitReady();
```

## Config / Infrastructure

### 14. `playwright.config.ts` without trace/video/screenshot

```ts
// Before
export default defineConfig({
  testDir: './tests/e2e',
  webServer: { command: 'pnpm run dev', url: '...' },
  use: { baseURL: '...' },
});

// After
export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [['html', { open: 'never' }], ['list']] : [['list']],
  expect: { timeout: 5_000 },
  use: {
    baseURL: '...',
    trace: 'on-first-retry',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
  ],
  webServer: { command: 'pnpm run preview:e2e', url: '...', reuseExistingServer: !process.env.CI },
});
```

**Why**: Without trace/video/screenshot, CI failures have no debug context. Production E2E requires these.

### 15. Test-only DOM signals hidden behind `import.meta.env.DEV`

```tsx
// Before
const dataTestProps = import.meta.env.DEV ? { 'data-chat-id': chatId } : {};
return <div data-testid="chat-panel" {...dataTestProps}>{children}</div>;

// After
return <div data-testid="chat-panel" data-chat-id={chatId}>{children}</div>;
```

**Why**: Gating a `data-*` attribute behind DEV means it's not present in production builds, including preview builds used for E2E. Tests silently break when switching to preview. `data-*` attributes are negligibly small and not a security concern — ship them everywhere.

## Process

### 16. Running format:check before the last edit

**Scenario**: You edit a markdown table row, making one row wider. You run `prettier --write`, which realigns column padding. `format:check` passes. Then you make one more small edit (e.g., changing a cell's text), which doesn't affect alignment. You commit without re-running format:check.

On CI, `format:check` fails because... wait, it wouldn't fail in this case. Let me rewrite this scenario.

**Actual scenario**: You edit a markdown table and add a row wider than all previous rows. Before running prettier, all old rows have the old column widths. You run `format:check` on the old state → passes. Then you save the new row. The new row changes the required column alignment for all rows. You don't re-run format:check because it "just passed." Commit → CI runs format:check → fails because column widths are now wrong for the new widest row.

**Fix**: After any edit to files prettier cares about (especially markdown tables), re-run `format:check` as the final step. Pre-push must be the very last state.

### 17. Treating pre-push differently from CI

**Before**: "Pre-push runs unit tests. CI runs format:check + lint + tsc + build + unit + e2e. Close enough."

**After**: Pre-push mirrors CI exactly. If CI runs format:check, pre-push runs format:check. If CI runs playwright, pre-push runs playwright (or explicitly skips it with a note). A broken CI caused by a pre-push gap is a process bug, not a test bug.

## Meta

### 18. Accepting "flaky" as a permanent attribute

When a test is labeled "flaky," investigate the root cause. Flakes usually have one of these causes:

1. **Hard wait** masking a race condition. Replace with a condition-based wait.
2. **Shared state** across tests. Isolate with fixtures.
3. **Timing assumption** that holds on fast machines but not slow ones. Use web-first assertions.
4. **Network variability** hitting a real service. Mock it or isolate it.
5. **Browser-specific bug** (MSW + Firefox reload is real). Document and work around.

"Retries fix it" is not a solution — it's a band-aid. Diagnose the underlying cause. If you genuinely can't, add retries + a `TODO: investigate flake` comment with the failure pattern so the next person has context.
