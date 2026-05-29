# Credential Setup

This document explains how `autonomous-claude-sandbox` provides credentials and configuration to the container, and how to fix the common failure modes.

## Why We Copy Instead of Mount

The naive approach is `docker run -v ~/.claude:/home/sandboxuser/.claude`. That works, but has two problems:

1. **Host state leaks in.** The container sees every session in `projects/`, every todo in `todos/`, all the paste cache, all the transcripts, etc. This pollutes the sandbox and provides attack surface.

2. **Host state leaks out.** The container's Claude Code session can write `settings.json`, `.claude.json`, and other config files that propagate back to the host. If the container runs into an error or has different settings, the host session is silently corrupted.

The launcher instead **copies** a curated subset of `~/.claude` (plus `~/.claude.json`) into a per-run temp directory and mounts the copy. The container can do whatever it wants with its copy — on exit, the whole temp dir is `rm -rf`'d. Host state is untouched.

## Exact Whitelist

Looking at `copy-claude-home.sh`:

**Copied into `$CLAUDE_HOME_COPY/.claude/`:**
- `.credentials.json` — OAuth tokens (REQUIRED for Claude Code to authenticate)
- `settings.json` — user preferences, permission allowlists, etc.
- `settings.local.json` — local override (if present)
- `CLAUDE.md` — user's global instructions
- `skills/` — the entire skills library (~23 MB on this machine)
- `commands/` — user-invocable skills (if populated)
- `agents/` — custom subagent definitions (if populated)
- `plugins/` — plugin definitions (if populated)

**Copied into `$CLAUDE_HOME_COPY/.claude.json`:**
- The top-level `~/.claude.json` that Claude Code reads from `$HOME`

**Explicitly excluded:**
- `projects/`, `todos/`, `tasks/` — per-host-session state, would confuse the fresh sandbox session
- `sessions/`, `transcripts/`, `file-history/`, `paste-cache/` — host activity history
- `history.jsonl`, `stats-cache.json` — tracking data
- `statsig/`, `telemetry/`, `ide/`, `debug/`, `backups/` — runtime metadata
- `shell-snapshots/`, `session-env/` — per-session environment captures
- `cache/`, `downloads/`, `chrome/` — large and irrelevant
- `config.json` — machine-specific state that could conflict

`cp -a` is used throughout so that `.credentials.json` keeps its `0600` permission. Claude Code refuses to load credentials that are world-readable, so `cp -r` (which would broaden permissions) would break authentication.

## Missing `~/.claude/.credentials.json` — macOS

Symptom: the launcher exits with

```
ERROR: Claude Code credentials not found at /Users/you/.claude/.credentials.json
```

Reason: on macOS, Claude Code stores OAuth tokens in the Keychain by default and only writes `.credentials.json` in specific circumstances. The Keychain is not accessible from inside the Docker container, so we need a file.

**Fix:**

```bash
# Find the Keychain service name (usually "Claude Code-credentials")
security dump-keychain 2>/dev/null | grep -i 'claude.*credential'

# Export the token to a file
security find-generic-password -s "Claude Code-credentials" -w > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
```

**Re-run the launcher.** The exported file is static — if your OAuth token rotates (e.g., after 90 days or a forced re-auth), you'll need to re-export.

## Missing `~/.claude/.credentials.json` — Linux

Symptom: same error message.

Reason: on Linux, Claude Code usually writes `.credentials.json` directly to disk at login time. If the file is missing, you probably never completed a login on this machine, or something deleted it.

**Fix:** start a fresh interactive Claude Code session on the host (`claude` with no args), complete the OAuth flow, confirm the file exists:

```bash
ls -l ~/.claude/.credentials.json
# Should show something like: -rw------- 1 you you 472 ...
```

Then re-run the launcher.

## Missing `~/.claude.json`

Symptom:

```
ERROR: /Users/you/.claude.json not found and no backup available.
Start a Claude Code session on the host first, then re-run.
```

Reason: `~/.claude.json` is the top-level Claude Code state file (different from `~/.claude/settings.json`, which is user preferences). It tracks installed plugins, recent projects, and onboarding state. Claude Code creates it automatically on first run, so a missing file usually means a very fresh install or an accidental delete.

**Fix:** The launcher automatically tries to restore from `~/.claude/backups/.claude.json.backup.*` if any exist. If no backup is available, start a Claude Code session on the host — it will recreate the file — then re-run.

## Credential Rotation

OAuth tokens rotate periodically. The symptom inside a sandbox run is a Claude Code error about expired credentials, which appears in the stream log but doesn't necessarily fail the container build.

When you see authentication errors in the sandbox output:

1. Re-authenticate on the host (run `claude` interactively, it handles re-auth)
2. Re-export `.credentials.json` if you're on macOS (see above)
3. Re-run the sandbox

There's no way to rotate credentials inside a running sandbox — the container's copy is frozen at launch time.

## Security Considerations

- The per-run temp dir (`$HOST_TEMP`) contains a copy of your OAuth token. It lives under `$TMPDIR` (usually `/tmp/` or `/var/folders/...` on macOS) with `0700` permissions inherited from `mktemp`. The `cleanup` trap `rm -rf`'s it on exit (success, failure, or signal).

- The stream log preserved at `$STREAM_LOG` may contain tool-use output that echoed credentials (unlikely but possible if the prompt explicitly asked Claude to print env vars). The `monitor-stream.sh` helper scrubs obvious patterns (`Bearer`, `token`, `sk-ant-*`) before display, but the raw stream log on disk is NOT scrubbed. Treat it as sensitive and gitignore your `artifacts/current/temp/` directory.

- If the launcher is killed hard (SIGKILL from the OS, not Ctrl+C), the cleanup trap does not fire and the temp dir stays on disk. Periodically check for leftover directories: `ls -la "${TMPDIR:-/tmp}"/claude-sandbox-* 2>/dev/null` and clean them manually if the launcher is not running.

- The Docker image itself contains no credentials — credentials are mounted at `docker run` time, not baked in at build time. So an abandoned image is safe to leave lying around (the launcher cleanup tries to remove it, but a forgotten image won't leak tokens).
