---
name: autonomous-claude-sandbox
description: >-
  Generic Docker sandbox infrastructure for running Claude Code with
  --dangerously-skip-permissions in an unattended, isolated container.
  Auto-detects project runtimes (Python / Node / Playwright), builds an
  ephemeral image, safely provisions credentials via a selective copy of
  ~/.claude (never mounts the host directory), runs `claude -p` with
  stream-json monitoring, and cleans up on exit. This is a utility skill
  meant to be leveraged by other skills — bdd-e2e-loop uses it for
  automated BDD verification, subagent-driven-development uses it for
  autonomous implementation runs. Trigger on phrases like "run in
  sandbox", "Docker claude", "autonomous run", "sandbox mode",
  "sandboxed execution", "跑 sandbox", "在 container 裡跑",
  "無人值守執行", or when any other skill needs unattended Claude Code
  execution with permission prompts disabled.
---

# Autonomous Claude Sandbox

Generic infrastructure for running `claude -p --dangerously-skip-permissions` inside an ephemeral Docker container. This skill provides the **sandbox launcher**; it does not orchestrate any specific workflow. Other skills own their own prompts and call `run-sandbox.sh` to execute them.

## When to Use

Use this skill (or call its launcher from another skill) when all of the following are true:

- The task involves running `claude -p` autonomously — no interactive human approvals
- The container needs access to Claude Code's skills, settings, and credentials
- You want strong isolation from the host: the sandbox must not mutate `~/.claude`, `~/.claude.json`, or any host files outside the mounted project directory
- The work should clean up after itself (image removed, temp dirs deleted)

**Do NOT use this skill directly for:**
- Interactive Claude Code sessions (no sandbox is needed; just run `claude` on the host)
- Running arbitrary bash commands that aren't `claude -p` (this launcher is scoped to Claude Code only)
- Long-lived containers that persist state between runs (the sandbox is intentionally ephemeral)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Host (caller skill)                                    │
│                                                        │
│  1. Caller pre-renders its prompt file                 │
│     (template variables already substituted)           │
│                                                        │
│  2. Caller invokes:                                    │
│     run-sandbox.sh --project-dir X --prompt-file Y     │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ run-sandbox.sh                                   │  │
│  │   • Selective copy ~/.claude → $HOST_TEMP/home   │  │
│  │   • detect-runtime.sh (Python/Node/Playwright)   │  │
│  │   • generate-dockerfile.sh → ephemeral Dockerfile│  │
│  │   • docker build (unique image tag)              │  │
│  │   • docker run in background                     │  │
│  │   • monitor-stream.sh (tail stream log)          │  │
│  │   • Trap cleanup: rmi, rm -rf temp               │  │
│  └──────────────────────────────────────────────────┘  │
│           │                                             │
│           ▼                                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Container                                        │  │
│  │   claude -p --dangerously-skip-permissions      │  │
│  │   --output-format stream-json --verbose          │  │
│  │                                                  │  │
│  │   Mounts:                                        │  │
│  │   • /workspace   = host project dir              │  │
│  │   • ~/.claude    = host-temp COPY of ~/.claude   │  │
│  │   • ~/.claude.json = host-temp COPY              │  │
│  │                                                  │  │
│  │   Host state is never mutated — the container    │  │
│  │   writes only to its copy, which is destroyed    │  │
│  │   on exit.                                       │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  3. Container exits → report file exists at            │
│     <project>/<expected-output>                        │
│                                                        │
│  4. Caller reads the report and takes action           │
└─────────────────────────────────────────────────────────┘
```

## Caller Interface

```bash
~/.claude/skills/autonomous-claude-sandbox/scripts/run-sandbox.sh \
  --project-dir <abs-path> \
  --prompt-file <abs-path-on-host> \
  [--expect-output <rel-path-in-workspace>] \
  [--stream-log <rel-path-in-workspace>] \
  [--progress-pattern <regex>] \
  [--browser-use] \
  [--playwright] \
  [--image-prefix <name>] \
  [--python-version X.Y] \
  [--node-version N] \
  [--timeout <seconds>]
```

**Required flags:**

- `--project-dir` — absolute path on the host. Mounted at `/workspace` inside the container.
- `--prompt-file` — absolute path to a fully-rendered prompt file on the host. The launcher does **not** do template substitution; the caller must pre-resolve its own template variables before calling. This keeps the launcher generic and avoids `sed` escaping issues with arbitrary values.

**Optional flags:**

- `--expect-output` — relative path (from `--project-dir`) where the launcher expects the prompt to have written a report. If the file is missing after the run, the launcher exits with code 2 even if Docker exited cleanly.
- `--stream-log` — where to tee stream-json output (relative to `--project-dir`). Default: `artifacts/current/temp/sandbox-stream.jsonl`. Preserved on exit for debugging.
- `--progress-pattern` — regex to grep from `Bash` tool-use commands in the stream log. If set, only matching commands are printed. If empty (default), all tool-use names are printed as they happen.
- `--browser-use` — install `browser-use` CLI + Chromium in the container. Forces Python >= 3.11.
- `--playwright` — force-install Playwright system deps + Chromium binary. Auto-detected from `package.json` but can be forced.
- `--image-prefix` — prefix for the ephemeral image tag (default: `claude-sandbox`). The full tag is `<prefix>-<pid>-<nanoseconds>` to prevent collisions between concurrent runs.
- `--python-version` / `--node-version` — override auto-detected runtime versions.
- `--timeout` — kill the container after N seconds. Useful for preventing runaway autonomous runs.

## Prerequisites (Checked by the Launcher)

- Docker installed and running
- `~/.claude/.credentials.json` exists and is non-empty
  - On macOS, if missing, the launcher prints Keychain export instructions
  - On Linux, the launcher prints a more generic "check the file exists" message
- `~/.claude.json` exists (or a backup under `~/.claude/backups/` can be restored)

The launcher will exit with a clear error message if any prerequisite is missing. It will not attempt to guess or silently patch over problems.

## What Gets Copied Into the Container

The launcher calls `copy-claude-home.sh` which does a selective whitelist copy of `~/.claude` into a per-run temp directory. The container mounts this **copy**, not the real `~/.claude`. See `references/credential-setup.md` for the exact include/exclude list.

Key guarantees:

- **Host state is immutable** — the container cannot write to host `~/.claude`, `~/.claude.json`, or anywhere outside `/workspace`
- **Per-session state is NOT copied** — `projects/`, `todos/`, `sessions/`, `transcripts/`, `history.jsonl` are excluded. The container starts fresh.
- **Skills ARE copied** — the container's Claude Code session can use the Skill tool with the user's full skill library (~23 MB copy, ~1s on SSD)
- **Credentials preserve permissions** — `cp -a` keeps `.credentials.json` at `0600`, which Claude Code enforces

## Known Consumers

| Skill | How it uses this launcher |
|---|---|
| `bdd-e2e-loop` | `scripts/bdd-sandbox.sh` pre-renders the Stage 1 BDD prompt, then calls `run-sandbox.sh` with `--progress-pattern '# [SJ]-[^\\]*'` and `--expect-output artifacts/current/temp/auto-stage-report.json`. Runs BDD verification scenarios in a loop. |
| `subagent-driven-development` | In Sandbox Mode, the skill pre-renders an orchestrator prompt that runs the full implementation loop (implementer → spec review → quality review → flow verification), calls `run-sandbox.sh`, and reads the completion report when the container exits. No commits happen inside the sandbox; the host makes one final commit after the container finishes. |

## Reference Files

- `references/caller-guide.md` — Step-by-step guide for other skills that want to call this launcher, with two worked examples (BDD and SDD)
- `references/dockerfile-anatomy.md` — Explains the Dockerfile generation logic: base image choice, non-root user rationale, optional toolchain layers
- `references/credential-setup.md` — How `~/.claude` is copied, what's included/excluded, and how to fix missing credentials on macOS and Linux

## Scripts

- `scripts/run-sandbox.sh` — main launcher (entry point for callers)
- `scripts/copy-claude-home.sh` — selective whitelist copy of `~/.claude`
- `scripts/detect-runtime.sh` — Python / Node / Playwright auto-detection (sourced)
- `scripts/generate-dockerfile.sh` — ephemeral Dockerfile generator (sourced)
- `scripts/monitor-stream.sh` — progress monitor for stream-json output (sourced)

## Key Principles

1. **Caller owns the prompt.** The launcher does not know anything about the task being performed. It takes a rendered prompt file and runs it. Template variable substitution, artifact validation, and report schema are all the caller's responsibility.

2. **Host state is untouchable.** The container mounts a **copy** of `~/.claude`, not the original. Nothing the container does can affect the host's Claude Code state.

3. **Ephemeral everything.** Image, temp claude copy, Dockerfile, cidfile — all destroyed on exit. The only persistent artifact is the stream log, which lives in the caller's `artifacts/current/temp/` for debugging.

4. **Unique image tags.** Concurrent runs (e.g., BDD sandbox + SDD sandbox in two worktrees) never collide because every run generates a PID-+-nanosecond-unique tag.

5. **Fail loudly, fail early.** Missing credentials, missing Docker, missing prompt file — the launcher exits immediately with a specific error message. No silent retries, no guessing.

6. **Strict scope: only `claude -p`.** The launcher is not a generic `docker run` wrapper. If you need to run arbitrary commands in a sandbox, use Docker directly or build a different tool.
