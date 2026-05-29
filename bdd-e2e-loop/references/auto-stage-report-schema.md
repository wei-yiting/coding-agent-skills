# Auto Stage Report Schema

The JSON file at `artifacts/current/temp/auto-stage-report.json` is the contract between Stage 1 (Docker automated verification) and Stage 2 (host interactive session). Stage 1 writes it; Stage 2 reads it.

## Schema

```json
{
  "status": "ALL_AUTO_PASS | DESIGN_ISSUES | MAX_ROUNDS_HIT",
  "rounds_completed": 3,
  "max_rounds": 5,
  "timestamp": "2026-04-01T14:30:00+08:00",

  "scenarios": {
    "S-auth-01": {
      "title": "Valid email login returns 200",
      "type": "Deterministic",
      "rounds": {
        "1": { "status": "FAIL", "expected": "HTTP 200", "actual": "HTTP 500", "details": "..." },
        "2": { "status": "PASS", "expected": "HTTP 200", "actual": "HTTP 200", "details": null }
      },
      "final_status": "PASS",
      "first_pass_round": 2,
      "ever_failed": true
    },
    "S-auth-02": {
      "title": "Missing email returns 400",
      "type": "Deterministic",
      "rounds": {
        "1": { "status": "PASS", "expected": "HTTP 400", "actual": "HTTP 400", "details": null },
        "2": { "status": "PASS", "expected": "HTTP 400", "actual": "HTTP 400", "details": null }
      },
      "final_status": "PASS",
      "first_pass_round": 1,
      "ever_failed": false
    }
  },

  "fix_history": [
    {
      "round": 1,
      "fixes": [
        {
          "scenario_id": "S-auth-01",
          "root_cause": "Missing try-catch in auth controller",
          "fix_description": "Added error handling for database connection failure",
          "files_changed": ["src/controllers/auth.py"]
        }
      ],
      "not_fixed": [
        {
          "scenario_id": "S-auth-05",
          "reason": "Rate limiting middleware not found in codebase"
        }
      ],
      "tests_run": [
        { "command": "pytest tests/", "result": "PASS", "notes": null }
      ]
    }
  ],

  "design_issues": [
    {
      "scenario_id": "S-auth-05",
      "title": "Rate limiting on failed login",
      "conflict": "Scenario expects HTTP 429 after 5 failed attempts, but rate limiting is not in the design spec",
      "consecutive_failures": 2,
      "analysis": "Fixer attempted to add rate limiting in rounds 1-2 but the feature was never specified in design",
      "user_decision": null
    }
  ],

  "regressions": [
    {
      "scenario_id": "S-auth-02",
      "regressed_in_round": 3,
      "was_passing_since_round": 1,
      "cause": "Round 3 fix for S-auth-05 modified shared middleware"
    }
  ]
}
```

## Field Reference

### Top-level

| Field | Type | Description |
|-------|------|-------------|
| `status` | enum | `ALL_AUTO_PASS`: all automated scenarios pass. `DESIGN_ISSUES`: stopped due to unresolved design issues. `MAX_ROUNDS_HIT`: reached round limit with remaining failures. |
| `rounds_completed` | int | How many rounds were executed |
| `max_rounds` | int | The round limit (5 for main loop, 3 for post-manual re-verification) |
| `timestamp` | ISO 8601 | When Stage 1 completed |

### `scenarios[id]`

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Scenario title from bdd-scenarios.md |
| `type` | enum | `Deterministic`, `Browser Automation`, `Manual Behavior Test`, `User Acceptance Test` |
| `rounds` | object | Per-round results. Key = round number (string). Only automated scenarios have round entries. |
| `rounds[N].status` | enum | `PASS`, `FAIL`, `ERROR`, `REGRESS` |
| `rounds[N].expected` | string | What the scenario expected |
| `rounds[N].actual` | string | What actually happened |
| `rounds[N].details` | string? | Additional context (stack traces, screenshots, timing). Null if pass. |
| `final_status` | enum | `PASS`, `FAIL`, `ERROR`, `PENDING` (for manual/UAT scenarios not yet tested) |
| `first_pass_round` | int? | First round this scenario passed. Null if never passed. |
| `ever_failed` | bool | Whether this scenario failed in any round. Used by report to filter "always passed" scenarios. |

### `fix_history[N]`

| Field | Type | Description |
|-------|------|-------------|
| `round` | int | Which round this fix was for |
| `fixes[].scenario_id` | string | Which scenario was fixed |
| `fixes[].root_cause` | string | Why it was failing |
| `fixes[].fix_description` | string | What was changed to fix it |
| `fixes[].files_changed` | string[] | Files modified |
| `not_fixed[].scenario_id` | string | Scenario that wasn't fixed this round |
| `not_fixed[].reason` | string | Why it wasn't fixed |
| `tests_run[]` | object | Unit test commands and results |

### `design_issues[N]`

| Field | Type | Description |
|-------|------|-------------|
| `scenario_id` | string | The scenario that triggered escalation |
| `title` | string | Scenario title |
| `conflict` | string | What the scenario expects vs what the code does |
| `consecutive_failures` | int | How many rounds this scenario failed consecutively |
| `analysis` | string | Why this is a design issue, not an implementation bug |
| `user_decision` | string? | Null until user decides in Stage 2. Set to user's choice. |

### `regressions[N]`

| Field | Type | Description |
|-------|------|-------------|
| `scenario_id` | string | The scenario that regressed |
| `regressed_in_round` | int | Which round the regression appeared |
| `was_passing_since_round` | int | Last round it was passing |
| `cause` | string | What likely caused the regression |

## Usage Notes

- Stage 2 reads `ever_failed` to decide which scenarios appear in the report's progression matrix and detail sections. Scenarios with `ever_failed: false` are counted in the "始終通過" summary line.
- `fix_history` provides the full fix narrative for Part 1 of the report.
- `design_issues` with `user_decision: null` are presented to the user in Stage 2 for resolution.
- Manual and UAT scenarios appear in `scenarios` with `final_status: "PENDING"` and no `rounds` entries. Stage 2 handles their verification.
