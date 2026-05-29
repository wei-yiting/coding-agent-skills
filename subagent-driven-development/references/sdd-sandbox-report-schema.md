# SDD Sandbox Report Schema

This is the JSON schema for `artifacts/current/temp/sdd-sandbox-report.json`, which the orchestrator Claude inside the sandbox writes when it finishes. The host controller reads this file after the sandbox exits and uses it to summarize the run for the user.

## File Location

```
<project>/artifacts/current/temp/sdd-sandbox-report.json
```

The sandbox launcher is told to expect this path via `--expect-output artifacts/current/temp/sdd-sandbox-report.json`, so if the file is missing when the container exits, the launcher reports an error.

## Schema

```json
{
  "status": "<SUCCESS | PARTIAL | ERROR>",
  "timestamp": "<ISO 8601>",
  "plan_file": "<relative path to the implementation plan that was executed>",

  "tasks": [
    {
      "id": "<task id or index>",
      "title": "<task title from the plan>",
      "status": "<completed | failed | skipped>",
      "implementer_rounds": <N>,
      "spec_review_rounds": <N>,
      "quality_review_rounds": <N>,
      "files_changed": ["<path relative to /workspace>", ...],
      "concerns": [
        {
          "level": "<observation | important | blocker>",
          "text": "<what the reviewer flagged>"
        }
      ],
      "fix_history": [
        {
          "round": <N>,
          "reviewer": "<spec | quality>",
          "issue": "<what was wrong>",
          "fix": "<what was changed>"
        }
      ],
      "failure_reason": "<why the task failed, if status=failed, else null>"
    }
  ],

  "flow_verifications": [
    {
      "name": "<flow name>",
      "status": "<passed | failed>",
      "steps_run": <N>,
      "failure_reason": "<details if failed, else null>"
    }
  ],

  "final_review": {
    "approved": <true | false>,
    "concerns": [
      {
        "level": "<observation | important | blocker>",
        "text": "<what the final reviewer flagged>"
      }
    ]
  },

  "linting": {
    "ran": <true | false>,
    "tool": "<ruff | eslint | ... | null>",
    "errors_fixed": <N>,
    "errors_remaining": <N>
  },

  "summary": {
    "total_tasks": <N>,
    "completed": <N>,
    "failed": <N>,
    "skipped": <N>,
    "total_files_changed": <N>,
    "blockers": <N>
  }
}
```

## Status Values

- **SUCCESS** — Every task in the plan was completed, every flow verification passed, the final code review approved, and linting is clean. The host can safely prompt the user to commit.
- **PARTIAL** — Some tasks completed, but at least one failed or was skipped due to a blocker the orchestrator couldn't resolve autonomously. The host should surface the failures and let the user decide whether to commit what was done, drop changes, or resume manually.
- **ERROR** — Something went wrong before the orchestrator could even attempt all tasks (e.g., plan file unreadable, subagent dispatch failed, tests infrastructure broken). The host should drop the changes and ask the user what happened.

## Concern Levels

- **observation** — Minor note, not a blocker. Examples: "this file is getting large", "consider extracting helper later".
- **important** — Should be addressed soon but not required for the task to be marked complete. Examples: "magic number that could be named", "missing docstring on public API".
- **blocker** — Must be fixed. A task cannot be marked `completed` if it has blocker-level concerns.

## Why These Fields

- `implementer_rounds` / `spec_review_rounds` / `quality_review_rounds` — Let the user see how hard the task was. If every task has `implementer_rounds=3`, the plan was probably under-specified.
- `fix_history` — Shows what the review loop did inside the container. Useful when debugging why a task was marked `failed` despite multiple fix attempts.
- `files_changed` — Aggregates across all rounds for a task. Helps the user build a mental map of the changeset before reviewing the diff.
- `flow_verifications` — Separate from tasks because they aren't implemented by a subagent; they're run directly by the orchestrator.
- `final_review` — Result of the final code-reviewer subagent that runs over the entire changeset after all tasks are complete.
- `linting.errors_remaining` — Must be 0 for `status=SUCCESS`. If non-zero, the orchestrator should have downgraded to `PARTIAL`.

## Example

```json
{
  "status": "SUCCESS",
  "timestamp": "2026-04-08T15:30:00Z",
  "plan_file": "artifacts/current/implementation.md",
  "tasks": [
    {
      "id": "1",
      "title": "Add hook installation script",
      "status": "completed",
      "implementer_rounds": 1,
      "spec_review_rounds": 1,
      "quality_review_rounds": 1,
      "files_changed": ["scripts/install-hook.sh", "tests/test_install_hook.py"],
      "concerns": [],
      "fix_history": [],
      "failure_reason": null
    },
    {
      "id": "2",
      "title": "Recovery modes",
      "status": "completed",
      "implementer_rounds": 2,
      "spec_review_rounds": 2,
      "quality_review_rounds": 2,
      "files_changed": ["src/recovery.py", "tests/test_recovery.py"],
      "concerns": [
        {
          "level": "observation",
          "text": "Consider extracting retry logic into a shared helper in next iteration"
        }
      ],
      "fix_history": [
        {
          "round": 1,
          "reviewer": "spec",
          "issue": "Missing progress reporting required by spec",
          "fix": "Added progress callback every 100 items"
        },
        {
          "round": 1,
          "reviewer": "quality",
          "issue": "Magic number 100",
          "fix": "Extracted PROGRESS_INTERVAL constant"
        }
      ],
      "failure_reason": null
    }
  ],
  "flow_verifications": [
    {
      "name": "Domain Event Pipeline",
      "status": "passed",
      "steps_run": 4,
      "failure_reason": null
    }
  ],
  "final_review": {
    "approved": true,
    "concerns": []
  },
  "linting": {
    "ran": true,
    "tool": "ruff",
    "errors_fixed": 3,
    "errors_remaining": 0
  },
  "summary": {
    "total_tasks": 2,
    "completed": 2,
    "failed": 0,
    "skipped": 0,
    "total_files_changed": 4,
    "blockers": 0
  }
}
```
