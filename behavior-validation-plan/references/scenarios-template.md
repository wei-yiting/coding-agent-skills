# BDD Scenarios Template

Follow this template exactly when writing `artifacts/current/bdd-scenarios.md`.

---

```markdown
# BDD Scenarios

## Meta
- Design Reference: `artifacts/current/design.md`
- Generated: {YYYY-MM-DD}
- Discovery Method: Three Amigos ({Agent Teams | Subagent Fallback})

---

## Feature: {feature name}

### Context
{1-2 sentences summarizing this feature's purpose from the design}

### Rule: {business rule or acceptance criterion}

#### S-{feature-abbrev}-{nn}: {scenario title}
> {One sentence: what this scenario verifies}

- **Given** {precondition — self-contained, no dependency on other scenarios}
- **When** {user action or system event}
- **Then** {expected outcome}

Category: Illustrative
Origin: PO | Dev | QA | Multiple

#### S-{feature-abbrev}-{nn}: {next scenario under this Rule}
...

### Rule: {next rule}

#### S-{feature-abbrev}-{nn}: ...
...

---

### Journey Scenarios

#### J-{feature-abbrev}-{nn}: {journey title}
> {One sentence: the complete E2E flow this journey covers}

- **Given** {starting state}
- **When** {high-level declarative description of the full user flow}
- **Then** {end state that proves E2E success}

Category: Journey
Origin: Multiple

#### J-{feature-abbrev}-{nn}: {next journey}
...

---

## Feature: {next feature}

### Context
...

### Rule: ...
...

### Journey Scenarios
...
```

---

## Template Notes

### Scenario IDs
- `S-` prefix for illustrative scenarios, `J-` prefix for journey scenarios
- Feature abbreviation: short and consistent (e.g., `auth`, `cart`, `onboard`)
- Numbering: sequential within each feature, starting at 01

### Origin Field
Which Three Amigos perspective originally proposed this scenario:
- `PO` — Product Owner identified it from a business value perspective
- `Dev` — Developer identified it from a technical boundary perspective
- `QA` — QA Tester identified it from a destructive testing perspective
- `Multiple` — More than one perspective independently discovered it (highest confidence)

### Given Steps
Must be self-contained. If a scenario needs a user to exist, the Given step creates that user — it does not rely on another scenario having run first. This ensures scenarios can execute independently and in any order.

### Journey Scenarios
Use high-level declarative steps. Describe the complete flow in terms of what the user accomplishes, not how buttons are clicked:
- Good: "When she completes registration, verifies her email, and sets up her profile"
- Avoid: "When she fills in the email field, clicks submit, opens her inbox, clicks the verification link, enters her name in the profile form, and clicks save"

Every Feature must have at least one Journey scenario.

### Rules
A Rule is a business rule or acceptance criterion extracted from the design. It explains why the scenarios beneath it exist and provides logical grouping. Examples:
- "Orders over $100 qualify for free shipping"
- "Email verification must complete within 24 hours"
- "Users with admin role can access the management dashboard"
