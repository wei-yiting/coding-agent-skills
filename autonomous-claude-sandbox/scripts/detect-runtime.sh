#!/usr/bin/env bash
#
# detect-runtime.sh — detect Python/Node/Playwright runtimes from a project directory
#
# This script is designed to be SOURCED by run-sandbox.sh, not executed directly.
# After sourcing, these variables are set in the caller's shell:
#
#   HAS_PYTHON          true | false
#   PYTHON_VERSION      e.g. "3.12" — major.minor only
#   PYTHON_PKG_MGR      uv | poetry | pipenv | pip | "" (none)
#
#   HAS_NODE            true | false
#   NODE_VERSION        major version, e.g. "20"
#   NODE_PKG_MGR        pnpm | yarn | npm | "" (none)
#   NODE_SUBDIR         relative path to package.json dir, empty if root
#
#   HAS_PLAYWRIGHT      true | false (Node @playwright/test in package.json)
#
# The caller is responsible for exporting PROJECT_DIR before sourcing.

: "${PROJECT_DIR:?PROJECT_DIR must be set before sourcing detect-runtime.sh}"

HAS_PYTHON=false
HAS_NODE=false
HAS_PLAYWRIGHT=false
PYTHON_VERSION="3.12"
PYTHON_PKG_MGR=""
NODE_VERSION="20"
NODE_PKG_MGR=""
NODE_SUBDIR=""

_detect_python() {
  if [[ ! -f "$PROJECT_DIR/pyproject.toml" && ! -f "$PROJECT_DIR/requirements.txt" && ! -f "$PROJECT_DIR/Pipfile" ]]; then
    return 0
  fi
  HAS_PYTHON=true

  if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    local ver
    ver=$(grep -m1 'requires-python' "$PROJECT_DIR/pyproject.toml" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)
    [[ -n "$ver" ]] && PYTHON_VERSION="$ver"
  fi

  if [[ -f "$PROJECT_DIR/uv.lock" ]]; then
    PYTHON_PKG_MGR="uv"
  elif [[ -f "$PROJECT_DIR/poetry.lock" ]]; then
    PYTHON_PKG_MGR="poetry"
  elif [[ -f "$PROJECT_DIR/Pipfile.lock" ]]; then
    PYTHON_PKG_MGR="pipenv"
  elif [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    PYTHON_PKG_MGR="pip"
  fi
}

_detect_node() {
  local pkg_dir=""
  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    pkg_dir="$PROJECT_DIR"
    NODE_SUBDIR=""
  else
    local found
    found=$(find "$PROJECT_DIR" -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      pkg_dir=$(dirname "$found")
      NODE_SUBDIR=$(python3 -c "import os; print(os.path.relpath('$pkg_dir', '$PROJECT_DIR'))" 2>/dev/null || echo "")
    fi
  fi

  [[ -z "$pkg_dir" ]] && return 0
  HAS_NODE=true

  if [[ -f "$PROJECT_DIR/.nvmrc" ]]; then
    local ver
    ver=$(tr -d 'v \n' < "$PROJECT_DIR/.nvmrc" | grep -oE '[0-9]+' | head -1 || true)
    [[ -n "$ver" ]] && NODE_VERSION="$ver"
  elif [[ -f "$PROJECT_DIR/.node-version" ]]; then
    local ver
    ver=$(tr -d 'v \n' < "$PROJECT_DIR/.node-version" | grep -oE '[0-9]+' | head -1 || true)
    [[ -n "$ver" ]] && NODE_VERSION="$ver"
  elif command -v jq &>/dev/null; then
    local ver
    ver=$(jq -r '.engines.node // empty' "$pkg_dir/package.json" 2>/dev/null \
      | grep -oE '[0-9]+' | head -1 || true)
    [[ -n "$ver" ]] && NODE_VERSION="$ver"
  fi

  if [[ -f "$pkg_dir/pnpm-lock.yaml" ]]; then
    NODE_PKG_MGR="pnpm"
  elif [[ -f "$pkg_dir/yarn.lock" ]]; then
    NODE_PKG_MGR="yarn"
  elif [[ -f "$pkg_dir/package-lock.json" ]]; then
    NODE_PKG_MGR="npm"
  fi

  if grep -q '"@playwright/test"' "$pkg_dir/package.json" 2>/dev/null; then
    HAS_PLAYWRIGHT=true
  fi
}

_detect_python
_detect_node

# If sourced, variables are already in the caller's shell. If executed directly,
# print an export block so callers can capture via eval.
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  cat <<EOF
export HAS_PYTHON=$HAS_PYTHON
export PYTHON_VERSION=$PYTHON_VERSION
export PYTHON_PKG_MGR=$PYTHON_PKG_MGR
export HAS_NODE=$HAS_NODE
export NODE_VERSION=$NODE_VERSION
export NODE_PKG_MGR=$NODE_PKG_MGR
export NODE_SUBDIR=$NODE_SUBDIR
export HAS_PLAYWRIGHT=$HAS_PLAYWRIGHT
EOF
fi
