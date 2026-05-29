#!/usr/bin/env bash
#
# run-sandbox.sh — Launch Claude Code inside an ephemeral Docker sandbox with
#                  --dangerously-skip-permissions for unattended autonomous runs.
#
# This is the generic infrastructure extracted from bdd-e2e-loop/scripts/bdd-sandbox.sh.
# It knows how to: build a runtime-appropriate container, copy ~/.claude safely,
# run `claude -p` with stream-json, monitor progress, and clean up. It knows
# NOTHING about BDD, scenarios, or any specific orchestration — callers pre-render
# their own prompt and pass it in.
#
# Usage:
#   run-sandbox.sh \
#     --project-dir <abs-path> \
#     --prompt-file <abs-path> \
#     [--expect-output <rel-path-in-workspace>] \
#     [--stream-log <rel-path-in-workspace>] \
#     [--progress-pattern <regex>] \
#     [--browser-use] \
#     [--playwright] \
#     [--image-prefix <name>] \
#     [--python-version X.Y] \
#     [--node-version N] \
#     [--timeout <seconds>]
#
# See references/caller-guide.md for detailed usage examples.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Argument parsing ───────────────────────────────────────────────────────

PROJECT_DIR=""
PROMPT_FILE=""
EXPECT_OUTPUT=""
STREAM_LOG_REL="artifacts/current/temp/sandbox-stream.jsonl"
PROGRESS_PATTERN=""
NEED_BROWSER_USE=false
FORCE_PLAYWRIGHT=false
IMAGE_PREFIX="claude-sandbox"
PYTHON_VERSION_OVERRIDE=""
NODE_VERSION_OVERRIDE=""
TIMEOUT_SECS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)       PROJECT_DIR="$2"; shift 2 ;;
    --prompt-file)       PROMPT_FILE="$2"; shift 2 ;;
    --expect-output)     EXPECT_OUTPUT="$2"; shift 2 ;;
    --stream-log)        STREAM_LOG_REL="$2"; shift 2 ;;
    --progress-pattern)  PROGRESS_PATTERN="$2"; shift 2 ;;
    --browser-use)       NEED_BROWSER_USE=true; shift ;;
    --playwright)        FORCE_PLAYWRIGHT=true; shift ;;
    --image-prefix)      IMAGE_PREFIX="$2"; shift 2 ;;
    --python-version)    PYTHON_VERSION_OVERRIDE="$2"; shift 2 ;;
    --node-version)      NODE_VERSION_OVERRIDE="$2"; shift 2 ;;
    --timeout)           TIMEOUT_SECS="$2"; shift 2 ;;
    -h|--help)
      sed -n '3,26p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" ]]; then
  echo "ERROR: --project-dir is required" >&2
  exit 1
fi
if [[ -z "$PROMPT_FILE" ]]; then
  echo "ERROR: --prompt-file is required" >&2
  exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi
PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"

# ─── Paths ──────────────────────────────────────────────────────────────────

ARTIFACTS_DIR="$PROJECT_DIR/artifacts/current"
TEMP_DIR="$ARTIFACTS_DIR/temp"
mkdir -p "$TEMP_DIR"

STREAM_LOG="$PROJECT_DIR/$STREAM_LOG_REL"
mkdir -p "$(dirname "$STREAM_LOG")"

# Ephemeral Dockerfile + per-run claude home copy live in an OS temp dir so they
# don't pollute the project's .artifacts directory.
HOST_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/${IMAGE_PREFIX}-XXXXXX")
DOCKERFILE_PATH="$HOST_TEMP/Dockerfile"
CLAUDE_HOME_COPY="$HOST_TEMP/home"
CIDFILE="$HOST_TEMP/container.id"

# Unique image tag per run — PID + nanosecond timestamp — to prevent concurrent runs
# from clobbering each other's images during cleanup.
IMAGE_NAME="${IMAGE_PREFIX}-$$-$(date +%s)$(printf '%09d' $((RANDOM * RANDOM)))"

CONTAINER_USER="sandboxuser"
CONTAINER_HOME="/home/$CONTAINER_USER"

export PROJECT_DIR DOCKERFILE_PATH CONTAINER_USER CONTAINER_HOME NEED_BROWSER_USE

# ─── Prerequisite checks ────────────────────────────────────────────────────

if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed or not in PATH." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running." >&2
  exit 1
fi

check_credentials() {
  local creds="$HOME/.claude/.credentials.json"

  if [[ -f "$creds" && -s "$creds" ]]; then
    echo "Credentials: found ($(wc -c < "$creds" | tr -d ' ') bytes)"
    return 0
  fi

  echo "" >&2
  echo "ERROR: Claude Code credentials not found at $creds" >&2
  echo "" >&2

  if [[ "${OSTYPE:-}" == "darwin"* ]]; then
    echo "On macOS, Claude Code stores OAuth tokens in the Keychain." >&2
    echo "To export them for Docker:" >&2
    echo "" >&2
    echo "  1. Find the Keychain service name:" >&2
    echo "     security dump-keychain 2>/dev/null | grep -i 'claude.*credential'" >&2
    echo "" >&2
    echo "  2. Export:" >&2
    echo "     security find-generic-password -s \"Claude Code-credentials\" -w > ~/.claude/.credentials.json" >&2
    echo "     chmod 600 ~/.claude/.credentials.json" >&2
  else
    echo "On Linux, check ~/.claude/.credentials.json exists and is not empty." >&2
    echo "Start a fresh Claude Code session on the host to regenerate if needed." >&2
  fi
  echo "" >&2
  exit 1
}

check_claude_json() {
  if [[ -f "$HOME/.claude.json" ]]; then
    echo "Config:      found ($(wc -c < "$HOME/.claude.json" | tr -d ' ') bytes)"
    return 0
  fi

  local backup
  backup=$(find "$HOME/.claude/backups" -name ".claude.json.backup.*" 2>/dev/null | sort -r | head -1 || true)
  if [[ -n "$backup" ]]; then
    echo "Config:      restoring from backup"
    cp "$backup" "$HOME/.claude.json"
    return 0
  fi

  echo "" >&2
  echo "ERROR: $HOME/.claude.json not found and no backup available." >&2
  echo "Start a Claude Code session on the host first, then re-run." >&2
  echo "" >&2
  exit 1
}

check_credentials
check_claude_json

# ─── Source helpers ─────────────────────────────────────────────────────────

# shellcheck source=./detect-runtime.sh
source "$SCRIPT_DIR/detect-runtime.sh"

# Apply CLI overrides on top of auto-detected values
[[ -n "$PYTHON_VERSION_OVERRIDE" ]] && PYTHON_VERSION="$PYTHON_VERSION_OVERRIDE"
[[ -n "$NODE_VERSION_OVERRIDE" ]] && NODE_VERSION="$NODE_VERSION_OVERRIDE"
[[ "$FORCE_PLAYWRIGHT" == "true" ]] && HAS_PLAYWRIGHT=true

export HAS_PYTHON PYTHON_VERSION PYTHON_PKG_MGR
export HAS_NODE NODE_VERSION NODE_PKG_MGR NODE_SUBDIR
export HAS_PLAYWRIGHT

echo ""
echo "=== Runtime Detection ==="
echo "Project:     $PROJECT_DIR"
echo "Python:      $HAS_PYTHON (version: $PYTHON_VERSION, pkg: ${PYTHON_PKG_MGR:-none})"
echo "Node:        $HAS_NODE (version: $NODE_VERSION, pkg: ${NODE_PKG_MGR:-none}${NODE_SUBDIR:+, subdir: $NODE_SUBDIR})"
echo "Playwright:  $HAS_PLAYWRIGHT"
echo "browser-use: $NEED_BROWSER_USE"
echo ""

# shellcheck source=./generate-dockerfile.sh
source "$SCRIPT_DIR/generate-dockerfile.sh"

# shellcheck source=./monitor-stream.sh
source "$SCRIPT_DIR/monitor-stream.sh"

# ─── Copy ~/.claude into per-run temp dir ───────────────────────────────────

echo "=== Preparing Claude home copy ==="
bash "$SCRIPT_DIR/copy-claude-home.sh" "$CLAUDE_HOME_COPY"
echo ""

# ─── Generate Dockerfile + build image ──────────────────────────────────────

generate_dockerfile

echo ""
echo "=== Building Docker Image ==="
echo "Image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" "$PROJECT_DIR"
echo ""

# ─── Cleanup trap ───────────────────────────────────────────────────────────

cleanup() {
  local exit_code=$?
  echo ""
  echo "=== Cleanup ==="

  # Stop container if still running (e.g., we were killed)
  if [[ -f "$CIDFILE" ]]; then
    local cid
    cid=$(cat "$CIDFILE" 2>/dev/null || true)
    if [[ -n "$cid" ]] && docker ps -q --no-trunc | grep -q "$cid"; then
      docker stop "$cid" >/dev/null 2>&1 || true
    fi
  fi

  # Remove image by unique tag (cannot collide with concurrent runs)
  docker rmi "$IMAGE_NAME" >/dev/null 2>&1 && echo "Removed image: $IMAGE_NAME" || true

  # Remove per-run temp dir (includes Dockerfile, claude home copy, cidfile)
  if [[ -d "$HOST_TEMP" ]]; then
    rm -rf "$HOST_TEMP" && echo "Removed temp dir: $HOST_TEMP" || true
  fi

  echo "Stream log preserved at: $STREAM_LOG"
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

# ─── Run the container ──────────────────────────────────────────────────────

echo "=== Running Claude Code in sandbox ==="
echo "Prompt file: $PROMPT_FILE"
echo "Stream log:  $STREAM_LOG"
[[ -n "$EXPECT_OUTPUT" ]] && echo "Expect:      $EXPECT_OUTPUT"
[[ -n "$TIMEOUT_SECS" ]] && echo "Timeout:     ${TIMEOUT_SECS}s"
echo ""

PROMPT_TEXT=$(<"$PROMPT_FILE")

# Shadow host node_modules with anonymous volumes so native binaries (macOS)
# don't conflict with the Linux container. pnpm install --frozen-lockfile will
# populate a clean node_modules inside the container.
NODE_MODULES_VOLUMES=()
if [[ "${HAS_NODE:-false}" == "true" ]]; then
  if [[ -n "${NODE_SUBDIR:-}" ]]; then
    NODE_MODULES_VOLUMES+=(-v "/workspace/$NODE_SUBDIR/node_modules")
  else
    NODE_MODULES_VOLUMES+=(-v "/workspace/node_modules")
  fi
fi

# Docker run in background so the host can monitor progress via stream log.
# Note: we mount the per-run claude home copy (not $HOME/.claude), so the
# container can never mutate host state.
docker run --rm \
  --cidfile "$CIDFILE" \
  -v "$PROJECT_DIR":/workspace \
  "${NODE_MODULES_VOLUMES[@]}" \
  -v "$CLAUDE_HOME_COPY/.claude":"$CONTAINER_HOME/.claude" \
  -v "$CLAUDE_HOME_COPY/.claude.json":"$CONTAINER_HOME/.claude.json" \
  -e CI=true \
  -e VITE_API_TARGET=http://host.docker.internal:8000 \
  --add-host=host.docker.internal:host-gateway \
  "$IMAGE_NAME" \
  --dangerously-skip-permissions \
  --output-format stream-json \
  --verbose \
  -p "$PROMPT_TEXT" \
  > "$STREAM_LOG" 2>&1 &

DOCKER_PID=$!
echo "Docker PID: $DOCKER_PID"
echo ""

# Timeout enforcement: background a watchdog that kills the docker process
if [[ -n "$TIMEOUT_SECS" ]]; then
  (
    sleep "$TIMEOUT_SECS"
    if kill -0 "$DOCKER_PID" 2>/dev/null; then
      echo "" >&2
      echo "TIMEOUT: sandbox exceeded ${TIMEOUT_SECS}s, killing container" >&2
      if [[ -f "$CIDFILE" ]]; then
        docker stop "$(cat "$CIDFILE")" >/dev/null 2>&1 || true
      fi
      kill "$DOCKER_PID" 2>/dev/null || true
    fi
  ) &
  WATCHDOG_PID=$!
fi

# Monitor progress (runs in foreground, blocks until docker exits)
monitor_stream "$DOCKER_PID" "$STREAM_LOG" "$PROGRESS_PATTERN"

wait "$DOCKER_PID" 2>/dev/null || true
DOCKER_EXIT=$?

if [[ -n "${WATCHDOG_PID:-}" ]]; then
  kill "$WATCHDOG_PID" 2>/dev/null || true
fi

echo ""
echo "=== Sandbox run complete ==="
echo "Docker exit code: $DOCKER_EXIT"

# ─── Report on expected output ──────────────────────────────────────────────

if [[ -n "$EXPECT_OUTPUT" ]]; then
  local_expected="$PROJECT_DIR/$EXPECT_OUTPUT"
  if [[ -f "$local_expected" ]]; then
    echo "Expected output found: $EXPECT_OUTPUT"
  else
    echo "WARNING: expected output NOT found: $EXPECT_OUTPUT" >&2
    echo "  Check $STREAM_LOG for clues." >&2
    if [[ "$DOCKER_EXIT" -eq 0 ]]; then
      DOCKER_EXIT=2  # distinguish "container ran clean but didn't produce output"
    fi
  fi
fi

exit "$DOCKER_EXIT"
