# Dockerfile Anatomy

This document explains what `generate-dockerfile.sh` produces and why each layer exists. Useful when debugging build failures or adjusting the launcher for a new runtime.

## Layer Order

The generated Dockerfile always follows this order. Layers marked **conditional** only appear when relevant flags are set or runtimes are detected.

```
1. Base image                                (always)
2. System tools: curl jq git ca-certs gnupg  (always)
3. Node.js                                   (always — needed by Claude Code CLI)
4. Claude Code CLI                           (always)
5. Node package manager                      (conditional: pnpm / yarn)
6. browser-use + Chromium                    (conditional: --browser-use)
7. Playwright system deps                    (conditional: --playwright or detected)
8. Create non-root user, USER switch         (always)
9. Playwright browser binary                 (conditional: same as 7)
10. Python package manager                   (conditional: uv / poetry / pipenv)
11. WORKDIR + ENTRYPOINT                     (always)
```

The non-root user switch in step 8 is a hard requirement — **Claude Code refuses to run with `--dangerously-skip-permissions` as root.** Anything that needs root install permissions (system packages, global npm installs, Chromium system deps) must happen **before** step 8. Anything that installs into the user's home (Playwright browser binary, `uv` per-user install) must happen **after** step 8.

## Base Image Selection

| Condition | Base image |
|---|---|
| `HAS_PYTHON=true` OR `NEED_BROWSER_USE=true` | `python:${PYTHON_VERSION}-slim` |
| `HAS_NODE=true` (but no Python) | `node:${NODE_VERSION}-slim` |
| Neither (pure shell project?) | `python:3.12-slim` (fallback) |

When `NEED_BROWSER_USE=true` and the detected Python version is below 3.11, the launcher upgrades to 3.11 because `browser-use` has a hard minimum requirement.

All images use `--platform=linux/amd64` because Claude Code CLI is only distributed for amd64 (no arm64 build as of 2025). On Apple Silicon hosts this means the container runs through QEMU emulation — slower but functional.

## Why Node Is Always Installed

The Claude Code CLI is distributed as `@anthropic-ai/claude-code` on npm. Even if the project under test is pure Python, the container needs Node to install and run the CLI. When the base image is already `node:*`, the dedicated Node install step is skipped.

## Non-Root User

```dockerfile
RUN useradd -m -s /bin/bash sandboxuser
USER sandboxuser
```

- Fixed username `sandboxuser` — referenced as `CONTAINER_USER` in the launcher and used to construct `CONTAINER_HOME=/home/sandboxuser`.
- `-m` creates the home directory so user-level installs (uv, poetry, playwright browsers) have somewhere to land.
- `-s /bin/bash` is optional but makes `docker exec -it ... bash` more pleasant for debugging.

The launcher mounts the per-run copy of `~/.claude` at `$CONTAINER_HOME/.claude` via `docker run -v`. Claude Code resolves `~/.claude` via `$HOME`, which defaults to `/home/sandboxuser` for the non-root user — so the mount path matches what Claude Code expects.

## Package Manager Detection vs Container Install

`detect-runtime.sh` looks at lock files on the host project and decides which package manager to install:

| Host lock file | `PYTHON_PKG_MGR` | Container install |
|---|---|---|
| `uv.lock` | `uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `poetry.lock` | `poetry` | `curl -sSL https://install.python-poetry.org \| python3 -` |
| `Pipfile.lock` | `pipenv` | `pip install --user pipenv` |
| `requirements.txt` | `pip` | no install — pip is in the base image |

| Host lock file | `NODE_PKG_MGR` | Container install |
|---|---|---|
| `pnpm-lock.yaml` | `pnpm` | `npm install -g pnpm` (as root) |
| `yarn.lock` | `yarn` | `npm install -g yarn` (as root) |
| `package-lock.json` | `npm` | no install — npm comes with Node |

`uv` is installed under the non-root user's home (not system-wide), so the Dockerfile sets `ENV PATH="$CONTAINER_HOME/.local/bin:$PATH"` for the user phase. If `browser-use` was also requested, `uv` was already installed as root — the Dockerfile installs it again for the non-root user (both installations are independent and won't conflict).

## browser-use and Playwright

Both browser automation stacks need Chromium and its system-level shared libraries. They install in two phases:

- **Root phase (before `USER` switch)**: install system deps — ALSA, glib, NSS, X libs, etc. Only root can `apt-get install`.
- **User phase (after `USER` switch)**: install the actual browser binary into the user's home — so Claude Code can find it via the default `~/.cache/ms-playwright/` path.

Mixing up the phases causes either "permission denied writing to /usr/share/..." or "browser binary not found" at runtime.

## ENTRYPOINT vs CMD

```dockerfile
ENTRYPOINT ["claude"]
```

The launcher passes flags via `docker run ... $IMAGE --dangerously-skip-permissions --output-format stream-json --verbose -p "$prompt"`. With ENTRYPOINT set to `claude`, these trailing arguments become arguments to `claude`. No shell expansion, no `CMD` defaults, no surprises.

## Debugging a Broken Build

If `docker build` fails, the launcher leaves the Dockerfile at `$HOST_TEMP/Dockerfile` — but because the cleanup trap fires on exit, it's gone by the time you see the error. To inspect:

1. Add `set -x` to `run-sandbox.sh` temporarily
2. Or: copy the Dockerfile to a persistent location BEFORE the build runs by inserting `cp "$DOCKERFILE_PATH" /tmp/last-sandbox.Dockerfile` just before `docker build`
3. Or: run the launcher with `bash -x run-sandbox.sh ...` and scroll up to find the Dockerfile contents in the trace output

For most issues, `docker build --progress=plain` (not set by default) produces clearer output than the default TTY builder. You can override by setting `DOCKER_BUILDKIT=0` before calling the launcher.
