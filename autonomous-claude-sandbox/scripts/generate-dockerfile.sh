#!/usr/bin/env bash
#
# generate-dockerfile.sh — emit an ephemeral Dockerfile for claude -p sandbox runs
#
# Designed to be SOURCED by run-sandbox.sh. Expects these variables to be set
# in the caller's shell (typically from detect-runtime.sh + run-sandbox.sh arg parsing):
#
#   PROJECT_DIR           — project root on host (used only for base image selection heuristics)
#   DOCKERFILE_PATH       — where to write the Dockerfile
#   CONTAINER_USER        — non-root username inside container (e.g. "sandboxuser")
#   CONTAINER_HOME        — non-root user home (e.g. "/home/sandboxuser")
#   HAS_PYTHON, PYTHON_VERSION, PYTHON_PKG_MGR
#   HAS_NODE, NODE_VERSION, NODE_PKG_MGR
#   HAS_PLAYWRIGHT
#   NEED_BROWSER_USE      — true | false
#
# Exposes one function: generate_dockerfile

: "${DOCKERFILE_PATH:?DOCKERFILE_PATH must be set}"
: "${CONTAINER_USER:?CONTAINER_USER must be set}"
: "${CONTAINER_HOME:?CONTAINER_HOME must be set}"

generate_dockerfile() {
  # ── Base image selection ──
  # browser-use requires Python >=3.11; force upgrade if caller asked for browser-use
  local python_ver="${PYTHON_VERSION:-3.12}"
  if [[ "${NEED_BROWSER_USE:-false}" == "true" ]]; then
    local major minor
    major=$(echo "$python_ver" | cut -d. -f1)
    minor=$(echo "$python_ver" | cut -d. -f2)
    if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 11 ]]; }; then
      echo "NOTE: Upgrading Python from $python_ver to 3.11 (browser-use requires >=3.11)"
      python_ver="3.11"
    fi
  fi

  local base_image
  if [[ "${HAS_PYTHON:-false}" == "true" || "${NEED_BROWSER_USE:-false}" == "true" ]]; then
    base_image="python:${python_ver}-slim"
  elif [[ "${HAS_NODE:-false}" == "true" ]]; then
    base_image="node:${NODE_VERSION:-20}-slim"
  else
    base_image="python:3.12-slim"
  fi

  cat > "$DOCKERFILE_PATH" <<EOF
FROM --platform=linux/amd64 $base_image

# System tools
RUN apt-get update && apt-get install -y \\
    curl jq git ca-certificates gnupg \\
    && rm -rf /var/lib/apt/lists/*
EOF

  # ── Node.js (always needed for Claude Code CLI) ──
  if ! echo "$base_image" | grep -q "^node:"; then
    cat >> "$DOCKERFILE_PATH" <<EOF

# Node.js ${NODE_VERSION:-20} (required for Claude Code CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION:-20}.x | bash - && \\
    apt-get install -y nodejs && \\
    rm -rf /var/lib/apt/lists/*
EOF
  fi

  # ── Claude Code CLI ──
  cat >> "$DOCKERFILE_PATH" <<'EOF'

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code
EOF

  # ── Node package managers (global install, needs root) ──
  case "${NODE_PKG_MGR:-}" in
    pnpm)
      cat >> "$DOCKERFILE_PATH" <<'EOF'

# pnpm
RUN npm install -g pnpm
EOF
      ;;
    yarn)
      cat >> "$DOCKERFILE_PATH" <<'EOF'

# yarn
RUN npm install -g yarn
EOF
      ;;
  esac

  # ── browser-use CLI + Chromium (root phase) ──
  if [[ "${NEED_BROWSER_USE:-false}" == "true" ]]; then
    cat >> "$DOCKERFILE_PATH" <<'EOF'

# uv (root — needed by browser-use install)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# browser-use CLI + Chromium + system deps
RUN pip install browser-use && \
    browser-use install

# browser-use Docker environment (required for headless container operation)
ENV IN_DOCKER=True
ENV BROWSER_USE_CHROME_NO_SANDBOX=1
ENV TIMEOUT_BrowserStartEvent=60.0
ENV TIMEOUT_BrowserLaunchEvent=60.0
ENV TIMEOUT_BrowserConnectedEvent=60.0
EOF
  fi

  # ── Playwright system deps (root phase) ──
  if [[ "${HAS_PLAYWRIGHT:-false}" == "true" ]]; then
    cat >> "$DOCKERFILE_PATH" <<'EOF'

# Playwright system deps (for Node @playwright/test)
RUN npx -y playwright install-deps chromium 2>/dev/null || true
EOF
  fi

  # ── Non-root user (required — Claude Code refuses --dangerously-skip-permissions as root) ──
  cat >> "$DOCKERFILE_PATH" <<EOF

# Non-root user (Claude Code refuses --dangerously-skip-permissions as root)
RUN useradd -m -s /bin/bash $CONTAINER_USER
USER $CONTAINER_USER
EOF

  # ── Playwright browser binary (non-root phase) ──
  if [[ "${HAS_PLAYWRIGHT:-false}" == "true" ]]; then
    cat >> "$DOCKERFILE_PATH" <<'EOF'

# Playwright Chromium browser binary (non-root)
RUN npx -y playwright install chromium
EOF
  fi

  # ── Python package managers (non-root phase) ──
  case "${PYTHON_PKG_MGR:-}" in
    uv)
      cat >> "$DOCKERFILE_PATH" <<EOF

# uv (non-root user)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="$CONTAINER_HOME/.local/bin:\$PATH"
EOF
      ;;
    poetry)
      cat >> "$DOCKERFILE_PATH" <<EOF

# poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="$CONTAINER_HOME/.local/bin:\$PATH"
EOF
      ;;
    pipenv)
      cat >> "$DOCKERFILE_PATH" <<'EOF'

# pipenv
RUN pip install --user pipenv
EOF
      ;;
    "")
      if [[ "${NEED_BROWSER_USE:-false}" == "true" ]]; then
        cat >> "$DOCKERFILE_PATH" <<EOF

# uv (non-root user — browser-use was installed, uv needed at runtime)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="$CONTAINER_HOME/.local/bin:\$PATH"
EOF
      fi
      ;;
  esac

  # ── Workdir + entrypoint ──
  cat >> "$DOCKERFILE_PATH" <<'EOF'

WORKDIR /workspace
ENTRYPOINT ["claude"]
EOF

  echo "Generated Dockerfile at $DOCKERFILE_PATH"
}
