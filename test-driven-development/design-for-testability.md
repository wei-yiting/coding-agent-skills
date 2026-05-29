# Design for Testability

The number and quality of your tests is largely decided *before* you write them — by the shape of the interface you're testing. A small, well-designed interface needs few tests and they stay stable; a wide, leaky one forces many brittle tests. If you find yourself writing a sprawl of tests, treat it as a design smell, not a testing problem.

## Deep Modules (small interface, deep implementation)

From John Ousterhout's *A Philosophy of Software Design*:

```
DEEP (prefer)                      SHALLOW (avoid)
┌─────────────────────┐            ┌─────────────────────────────────┐
│   Small interface   │ few        │       Large interface           │ many
├─────────────────────┤ methods    ├─────────────────────────────────┤ methods
│                     │            │  Thin implementation            │ (mostly
│  Deep implementation│ complexity └─────────────────────────────────┘  pass-
│  (complexity hidden)│ hidden                                          through)
└─────────────────────┘
```

- **Deep module** = small interface + lots of implementation behind it. Callers learn a little, get a lot. Few public methods → few things to test.
- **Shallow module** = large interface + little behind it. Callers must understand a lot for little payoff, and every method is another test you must write and maintain.

When designing an interface, ask:
- Can I reduce the number of public methods?
- Can I simplify the parameters?
- Can I hide more complexity inside, behind the same small surface?

**Fewer methods = fewer tests needed.** This is the most direct lever you have on test count.

## Three Properties That Make Code Naturally Testable

### 1. Accept dependencies, don't create them

Inject what a function depends on so a test can pass a fake or stub without monkey-patching globals.

```typescript
// Testable — the test supplies the gateway
function processOrder(order, paymentGateway) { ... }

// Hard to test — the dependency is hardcoded inside
function processOrder(order) {
  const gateway = new StripeGateway();
  ...
}
```

### 2. Return results, don't mutate hidden state

A function that returns its result can be tested with a single assertion on the return value. A function that mutates shared state forces the test to reconstruct and inspect that state.

```typescript
// Testable — assert on the returned value
function calculateDiscount(cart): Discount { ... }

// Hard to test — must inspect cart afterwards
function applyDiscount(cart): void { cart.total -= discount; }
```

### 3. Small surface area

Fewer methods means fewer tests; fewer parameters means simpler setup. Every extra knob on the interface is multiplied across every test that touches it.

## Mocking Follows From Design

Mock only at **system boundaries** — external APIs, payment/email services, the clock, randomness, sometimes the database or filesystem. Do *not* mock your own classes or internal collaborators; if a test needs to mock something you control, that's usually a sign the design is too coupled (apply dependency injection instead).

At the boundaries you do mock, prefer **SDK-style interfaces** over one generic fetcher — each operation becomes independently mockable with a single fixed return shape, instead of a mock that has to branch on its arguments.

```typescript
// GOOD: each function mocks to one specific shape, no conditional logic in the mock
const api = {
  getUser:    (id)     => fetch(`/users/${id}`),
  getOrders:  (userId) => fetch(`/users/${userId}/orders`),
  createOrder:(data)   => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: mocking requires branching inside the mock on `endpoint`
const api = {
  request: (endpoint, options) => fetch(endpoint, options),
};
```

## The Connection Back to TDD

This is why interface design belongs in the TDD loop, not after it. When you write the test first, a hard-to-write test is immediate feedback that the interface is wrong — too wide, too coupled, or mutating hidden state. Listen to that signal and reshape the interface *before* implementing, rather than papering over a bad design with a pile of mocks and setup.
