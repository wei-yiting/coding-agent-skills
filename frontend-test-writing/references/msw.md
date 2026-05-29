# MSW (Mock Service Worker) — Deep Dive

Covers MSW setup for both Node (Vitest integration tests) and the browser (Playwright E2E). Read this when adding a mocked endpoint, debugging a handler that isn't intercepting, or wiring MSW into a preview build for E2E.

## The Two Runtimes

MSW runs in two environments with slightly different setup; handler objects are identical across them.

| Runtime | Used by | Transport |
|---|---|---|
| `msw/node` | Vitest / Jest integration tests | Intercepts `fetch` / `XHR` in Node |
| `msw/browser` | Playwright / real browser | Service worker registered in-page |

## Handler Structure

```ts
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/user/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'Ada' });
  }),
  http.post('/api/session', async ({ request }) => {
    const body = (await request.json()) as { email: string };
    if (!body.email) return new HttpResponse(null, { status: 400 });
    return HttpResponse.json({ token: 'abc123' });
  }),
  http.get('/api/slow', async () => {
    await new Promise((r) => setTimeout(r, 500));
    return HttpResponse.json({ ok: true });
  }),
];
```

- Use `HttpResponse.json(body, init?)` for JSON — sets `Content-Type` automatically.
- Return `new HttpResponse(null, { status: 500 })` for bodiless error responses.
- `request.json()`, `request.formData()`, `request.text()` are Web-API Request methods — same as in production handlers.

## Node Setup — Vitest

```ts
// src/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

```ts
// src/setupTests.ts
import { server } from './mocks/server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

`onUnhandledRequest: 'error'` is the safer default for tests — silent pass-through makes debugging "why is this hitting the real API?" painful.

## Per-Test Overrides

`server.use(...)` adds handlers **on top of** the defaults, and `resetHandlers()` (in `afterEach`) rolls them back:

```ts
test('500 response surfaces the error UI', async () => {
  server.use(
    http.get('/api/user/:id', () => new HttpResponse(null, { status: 500 }))
  );

  render(<UserCard id="42" />);
  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

This is the idiomatic per-case pattern — keeps handlers declarative and prevents leakage.

## Browser Setup — Playwright E2E

```ts
// src/mocks/browser.ts
import { setupWorker } from 'msw/browser';
import { handlers } from './handlers';

export const worker = setupWorker(...handlers);
```

Started from the app entry, **gated** so it never ships to production:

```ts
// main.tsx
async function enableMocking() {
  const mode = import.meta.env.MODE;
  if (mode !== 'development' && mode !== 'e2e') return;
  if (!new URLSearchParams(location.search).has('msw_fixture')) return;

  const { worker } = await import('./mocks/browser');
  await worker.start({ onUnhandledRequest: 'bypass' });
}

enableMocking().then(() => {
  ReactDOM.createRoot(document.getElementById('root')!).render(<App />);
});
```

`onUnhandledRequest: 'bypass'` is correct for browser — you don't want analytics beacons or HMR pings to fail the test. Generate the service worker file once with `pnpm exec msw init public/`.

## Fixture-Routed Handlers

A common pattern: let the E2E URL pick which mock dataset the app sees.

```ts
// src/mocks/handlers.ts
const fixtures: Record<string, () => Response> = {
  'happy-text': () => HttpResponse.json({ text: 'hello' }),
  '500': () => new HttpResponse(null, { status: 500 }),
  'slow': async () => {
    await new Promise((r) => setTimeout(r, 2000));
    return HttpResponse.json({ text: 'finally' });
  },
};

export const handlers = [
  http.post('/api/chat', ({ request }) => {
    const referer = request.headers.get('referer') ?? '';
    const fixtureName = new URL(referer).searchParams.get('msw_fixture') ?? 'happy-text';
    return (fixtures[fixtureName] ?? fixtures['happy-text'])();
  }),
];
```

Important: read the fixture name from **`Referer`**, not `request.url`. The intercepted `fetch` inside the app won't carry the page's query string — it carries the API URL the app called.

From a Playwright spec:

```ts
await page.goto('/?msw_fixture=500');
// app makes its normal fetch; handler routes to the '500' branch
```

## preview vs dev — Mode-Gated MSW

`vite dev` serves uncompiled modules; `vite preview` serves the production bundle. E2E should run against `preview` to catch tree-shaking and minification edge cases. Add a dedicated mode so MSW still loads:

```json
// package.json
"preview:e2e": "vite build --mode e2e && vite preview"
```

Then gate MSW on `mode === 'e2e' || mode === 'development'`. Keeps MSW out of real production while enabling it for E2E.

## Firefox Service-Worker Trap

`worker.start()` can hang on **page reload** in Firefox when the service worker is already registered from a previous run. Two workarounds:

1. **Render-fallback timeout** in `main.tsx` so React mounts regardless:

   ```ts
   await Promise.race([
     enableMocking(),
     new Promise((r) => setTimeout(r, 3000)),
   ]);
   ```

2. **Exclude reload-dependent specs** from the Firefox project:

   ```ts
   // playwright.config.ts
   { name: 'firefox', testIgnore: /critical\/refresh-invariant/ },
   ```

## Common Pitfalls

1. **Handler order matters** — the first matching handler wins; put specific paths before generic ones.
2. **`onUnhandledRequest` mismatch** — `'error'` is right for Node tests (catches leaks); `'bypass'` is right for browser (allows infra calls).
3. **Forgetting `resetHandlers()` in `afterEach`** — per-test `server.use(...)` leaks to the next test.
4. **Absolute vs relative URLs** — `http.get('/api/x')` matches relative fetches. If the app uses a full base URL, match it: `http.get('https://api.example.com/x')`.
5. **Worker registration race** — if the app's first request fires before `worker.start()` resolves, MSW misses it. Always `await` the start call before mounting React.

## Sources

- [MSW — Best Practices](https://mswjs.io/docs/best-practices/)
- [MSW — Node Setup](https://mswjs.io/docs/integrations/node)
- [MSW — Browser Setup](https://mswjs.io/docs/integrations/browser)
