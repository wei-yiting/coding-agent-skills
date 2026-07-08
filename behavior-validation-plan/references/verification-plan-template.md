# Verification Plan Template

Follow this template exactly when writing `artifacts/current/verification-plan.md`.

---

```markdown
# Verification Plan

## Meta

- Scenarios Reference: `artifacts/current/bdd-scenarios.md`
- Generated: {YYYY-MM-DD}

---

## Automated Verification

### Deterministic

#### S-{id}: {scenario title}

- **Method**: {curl | script | log grep | DB query}
- **Steps**:
  1. {concrete command or action}
  2. {next step}
- **Expected**: {what success looks like — status code, output content, state change}

#### S-{id}: {next scenario}

...

### Browser Automation

#### S-{id}: {scenario title}

- **Method**: Browser automation (Playwright script)
- **Steps**:
  1. {navigation or action}
  2. {next step}
- **Checkpoints**: {where to screenshot, what to compare against design mockup}
- **Expected**: {visual match with design, functional behavior confirmed}

#### J-{id}: {journey scenario — full UI flow}

- **Method**: Browser automation (Playwright script)
- **Steps**:
  1. {first stage of the journey}
  2. {next stage}
  3. {final stage}
- **Checkpoints**: {screenshot at each key stage, compare against design mockups}
- **Expected**: {end-to-end flow completes, all checkpoints match design}

---

## Manual Verification

### Manual Behavior Test

> Tests the Coding Agent cannot execute automatically. User performs these to complete E2E verification.

#### S-{id}: {scenario title}

- **Reason**: {why this can't be automated — needs physical device, high concurrency, external service, etc.}
- **Steps**:
  1. {what the user should do}
  2. {next step}
- **Expected**: {what success looks like}

### User Acceptance Test

> User validates that the overall result meets requirements. This is acceptance testing from the Product Owner perspective.

#### S-{id}: {scenario title}

- **Acceptance Question**: {the question this test answers — e.g., "Does the onboarding flow feel intuitive?"}
- **Steps**:
  1. {what the user should do}
  2. {next step}
- **Expected**: {acceptance criteria from the design}
```

---

## Template Notes

### Scenario ID Consistency

Every scenario ID (`S-` or `J-`) in this file must correspond to a scenario in `bdd-scenarios.md`. If a scenario appears there, it must appear here with a verification method.

### Specificity Principle

Write concrete commands, URLs, and payloads for everything derivable from the design:

- API paths defined in the design → write the full curl command
- UI routes defined in the design → write the Playwright script steps (`webapp-testing` skill)
- CLI commands defined in the design → write the complete invocation

Use `[POST-CODING: {description}]` only for information that genuinely requires the codebase after implementation:

- `[POST-CODING: look up the exact function name for user creation]`
- `[POST-CODING: find the log pattern for authentication events]`
- `[POST-CODING: determine the CLI entry point command]`

