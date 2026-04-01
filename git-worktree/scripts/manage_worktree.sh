#!/bin/bash

set -euo pipefail

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

show_usage() {
    cat << 'EOF'
Usage: manage_worktree.sh <command> [options]

Commands:
  create <branch-name>
      Create a new worktree branch and optionally bootstrap local environment.
      Options:
        --base <branch>      Base branch (default: current branch)
        --install-deps       Auto-detect package managers and install dependencies
        --start-docker       Start docker services if compose file exists
        --no-env-copy        Skip syncing .env* files

  finish <branch-name>
      Validate worktree is clean, optionally remove it, and optionally switch main tree.
      Options:
        --switch             Switch main worktree to branch after finishing
        --no-remove          Keep worktree directory
        --no-env-sync-back   Skip syncing .env* files back to main repo

  list
      List active worktrees.

  remove <branch-name>
      Remove a worktree.
      Options:
        --force              Remove even with uncommitted changes
        --no-env-sync-back   Skip syncing .env* files back to main repo

  sync-env <branch-name>
      Sync .env* files from main repository to target worktree.

  help
      Show this help message.

Examples:
  manage_worktree.sh create feature/add-login
  manage_worktree.sh create feature/add-login --base main --install-deps --start-docker
  manage_worktree.sh finish feature/add-login --switch
  manage_worktree.sh sync-env feature/add-login
EOF
}

ensure_in_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Current directory is not inside a git repository."
        exit 1
    fi
}

init_project_context() {
    local detected_root
    local gitdir_line
    local worktree_gitdir
    local main_git_dir

    detected_root="$(git rev-parse --show-toplevel)"

    if [ -f "$detected_root/.git" ]; then
        IFS= read -r gitdir_line < "$detected_root/.git"
        worktree_gitdir="${gitdir_line#gitdir: }"

        if [[ "$worktree_gitdir" != /* ]]; then
            worktree_gitdir="$detected_root/$worktree_gitdir"
        fi

        worktree_gitdir="$(cd "$worktree_gitdir" && pwd)"
        main_git_dir="$(dirname "$(dirname "$worktree_gitdir")")"
        PROJECT_ROOT="$(dirname "$main_git_dir")"
    else
        PROJECT_ROOT="$detected_root"
    fi

    PROJECT_NAME="$(basename "$PROJECT_ROOT")"
    WORKTREE_PREFIX="${PROJECT_NAME}"
}

sanitize_branch_name() {
    local branch_name="$1"
    local sanitized

    sanitized="${branch_name//[\/:[:space:]]/-}"
    sanitized="${sanitized//[^A-Za-z0-9._-]/-}"

    echo "$sanitized"
}

strip_branch_type_prefix() {
    local branch_name="$1"
    echo "$branch_name" | sed -E 's|^(feat|feature|fix|bugfix|hotfix|refactor|docs|experiment|chore)/||'
}

get_worktree_path() {
    local branch_name="$1"
    local stripped
    stripped="$(strip_branch_type_prefix "$branch_name")"
    local sanitized
    sanitized="$(sanitize_branch_name "$stripped")"
    echo "$(dirname "$PROJECT_ROOT")/${WORKTREE_PREFIX}-${sanitized}"
}

has_uncommitted_changes() {
    local repo_path="$1"
    if [ -n "$(git -C "$repo_path" status --porcelain)" ]; then
        return 0
    fi
    return 1
}

collect_env_files() {
    local root="$1"
    local env_files=()
    local file
    local dir
    local app_dir

    for file in "$root"/.env*; do
        if [ -f "$file" ]; then
            env_files+=("$file")
        fi
    done

    for dir in backend frontend server client; do
        if [ -d "$root/$dir" ]; then
            for file in "$root/$dir"/.env*; do
                if [ -f "$file" ]; then
                    env_files+=("$file")
                fi
            done
        fi
    done

    if [ -d "$root/apps" ]; then
        for app_dir in "$root/apps"/*; do
            if [ -d "$app_dir" ]; then
                for file in "$app_dir"/.env*; do
                    if [ -f "$file" ]; then
                        env_files+=("$file")
                    fi
                done
            fi
        done
    fi

    if [ ${#env_files[@]} -gt 0 ]; then
        printf '%s\n' "${env_files[@]}"
    fi
}

sync_env_files_to_worktree() {
    local worktree_path="$1"
    local copied=0
    local src
    local rel
    local dst

    log_info "Scanning and syncing .env* files..."

    while IFS= read -r src; do
        if [ -z "$src" ]; then
            continue
        fi

        rel="${src#"$PROJECT_ROOT"/}"
        dst="$worktree_path/$rel"

        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        copied=$((copied + 1))
        log_success "Copied $rel"
    done < <(collect_env_files "$PROJECT_ROOT")

    if [ "$copied" -eq 0 ]; then
        log_warn "No .env* files found in root/common subdirectories/apps/*"
    else
        log_success "Synced $copied env file(s)"
    fi
}

sync_env_files_from_worktree() {
    local worktree_path="$1"
    local copied=0
    local src
    local rel
    local dst

    log_info "Syncing .env* files from worktree back to main repo..."

    while IFS= read -r src; do
        if [ -z "$src" ]; then
            continue
        fi

        rel="${src#"$worktree_path"/}"
        dst="$PROJECT_ROOT/$rel"

        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        copied=$((copied + 1))
        log_success "Synced back $rel"
    done < <(collect_env_files "$worktree_path")

    if [ "$copied" -eq 0 ]; then
        log_info "No .env* files to sync back"
    else
        log_success "Synced $copied env file(s) back to main repo"
    fi
}

detect_dir_package_manager() {
    local dir="$1"
    local pyproject_file="$dir/pyproject.toml"

    if [ -f "$dir/uv.lock" ]; then
        echo "uv"
        return
    fi
    if [ -f "$pyproject_file" ] && grep -q "^\[tool\.uv\]" "$pyproject_file"; then
        echo "uv"
        return
    fi

    if [ -f "$dir/poetry.lock" ]; then
        echo "poetry"
        return
    fi
    if [ -f "$pyproject_file" ] && grep -q "^\[tool\.poetry\]" "$pyproject_file"; then
        echo "poetry"
        return
    fi

    if [ -f "$dir/Pipfile.lock" ] || [ -f "$dir/Pipfile" ]; then
        echo "pipenv"
        return
    fi

    if [ -f "$dir/requirements.txt" ]; then
        echo "pip"
        return
    fi

    if [ -f "$dir/pnpm-lock.yaml" ]; then
        echo "pnpm"
        return
    fi

    if [ -f "$dir/yarn.lock" ]; then
        echo "yarn"
        return
    fi

    if [ -f "$dir/package-lock.json" ]; then
        echo "npm"
        return
    fi

    if [ -f "$dir/package.json" ]; then
        echo "pnpm"
        return
    fi

    if [ -f "$dir/bun.lockb" ] || [ -f "$dir/bun.lock" ]; then
        echo "bun"
        return
    fi

    if [ -f "$dir/Cargo.toml" ]; then
        echo "cargo"
        return
    fi

    if [ -f "$dir/go.mod" ]; then
        echo "go"
        return
    fi
}

run_install_for_manager() {
    local manager="$1"
    local dir="$2"
    local rel_dir

    rel_dir="${dir#"$PROJECT_ROOT"/}"
    if [ "$dir" = "$PROJECT_ROOT" ]; then
        rel_dir="."
    fi

    log_info "Installing dependencies in $rel_dir using $manager"

    case "$manager" in
        uv)
            command -v uv >/dev/null 2>&1 || { log_error "uv is not installed"; return 1; }
            (cd "$dir" && uv sync)
            ;;
        poetry)
            command -v poetry >/dev/null 2>&1 || { log_error "poetry is not installed"; return 1; }
            (cd "$dir" && poetry install)
            ;;
        pipenv)
            command -v pipenv >/dev/null 2>&1 || { log_error "pipenv is not installed"; return 1; }
            (cd "$dir" && pipenv install)
            ;;
        pip)
            command -v pip >/dev/null 2>&1 || { log_error "pip is not installed"; return 1; }
            (cd "$dir" && pip install -r requirements.txt)
            ;;
        pnpm)
            command -v pnpm >/dev/null 2>&1 || { log_error "pnpm is not installed"; return 1; }
            (cd "$dir" && pnpm install)
            ;;
        yarn)
            command -v yarn >/dev/null 2>&1 || { log_error "yarn is not installed"; return 1; }
            (cd "$dir" && yarn install)
            ;;
        npm)
            command -v npm >/dev/null 2>&1 || { log_error "npm is not installed"; return 1; }
            (cd "$dir" && npm install)
            ;;
        bun)
            command -v bun >/dev/null 2>&1 || { log_error "bun is not installed"; return 1; }
            (cd "$dir" && bun install)
            ;;
        cargo)
            command -v cargo >/dev/null 2>&1 || { log_error "cargo is not installed"; return 1; }
            (cd "$dir" && cargo build)
            ;;
        go)
            command -v go >/dev/null 2>&1 || { log_error "go is not installed"; return 1; }
            (cd "$dir" && go mod download)
            ;;
        *)
            log_warn "Unknown package manager '$manager' in $rel_dir"
            ;;
    esac

    log_success "Dependency install completed in $rel_dir"
}

install_detected_dependencies() {
    local root="$1"
    local dirs=()
    local dir
    local child
    local manager
    local installed_count=0

    dirs+=("$root")

    for child in "$root"/*; do
        if [ -d "$child" ]; then
            dirs+=("$child")
            if [ "$(basename "$child")" = "apps" ]; then
                for dir in "$child"/*; do
                    if [ -d "$dir" ]; then
                        dirs+=("$dir")
                    fi
                done
            fi
        fi
    done

    for dir in "${dirs[@]}"; do
        manager="$(detect_dir_package_manager "$dir" || true)"
        if [ -n "$manager" ]; then
            run_install_for_manager "$manager" "$dir"
            installed_count=$((installed_count + 1))
        fi
    done

    if [ "$installed_count" -eq 0 ]; then
        log_warn "No supported package manager files detected."
    else
        log_success "Processed dependency installation for $installed_count location(s)."
    fi
}

find_compose_file() {
    local root="$1"
    local file

    for file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [ -f "$root/$file" ]; then
            echo "$root/$file"
            return
        fi
    done
}

start_docker_services() {
    local root="$1"
    local compose_file

    compose_file="$(find_compose_file "$root" || true)"
    if [ -z "$compose_file" ]; then
        log_warn "No compose file found. Skipping Docker startup."
        return 0
    fi

    command -v docker >/dev/null 2>&1 || { log_error "docker is not installed"; return 1; }
    if ! docker compose version >/dev/null 2>&1; then
        log_error "'docker compose' is unavailable. Install Docker Compose v2 plugin."
        return 1
    fi

    log_info "Starting Docker services with $(basename "$compose_file")"
    (cd "$root" && docker compose -f "$compose_file" up -d)
    log_success "Docker services started"
}

cmd_create() {
    local branch_name=""
    local base_branch=""
    local base_branch_ref=""
    local install_deps=false
    local start_docker=false
    local no_env_copy=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --base)
                if [ $# -lt 2 ]; then
                    log_error "--base requires a value"
                    return 1
                fi
                base_branch="$2"
                shift 2
                ;;
            --install-deps)
                install_deps=true
                shift
                ;;
            --start-docker)
                start_docker=true
                shift
                ;;
            --no-env-copy)
                no_env_copy=true
                shift
                ;;
            --help|-h)
                show_usage
                return 0
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name="$1"
                    shift
                else
                    log_error "Unknown argument: $1"
                    return 1
                fi
                ;;
        esac
    done

    if [ -z "$branch_name" ]; then
        log_error "Branch name is required"
        show_usage
        return 1
    fi

    if [ -z "$base_branch" ]; then
        base_branch="$(git -C "$PROJECT_ROOT" branch --show-current)"
        log_info "Using current branch '$base_branch' as base"
    fi

    if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$base_branch"; then
        base_branch_ref="$base_branch"
    elif git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
        base_branch_ref="origin/$base_branch"
        log_info "Using remote-tracking base '$base_branch_ref'"
    else
        log_error "Base branch '$base_branch' does not exist locally or on origin."
        return 1
    fi

    local worktree_path
    worktree_path="$(get_worktree_path "$branch_name")"

    if [ -e "$worktree_path" ]; then
        log_error "Target worktree path already exists: $worktree_path"
        return 1
    fi

    log_info "Creating worktree at: $worktree_path"

    if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_info "Branch '$branch_name' already exists. Attaching existing branch."
        if ! git -C "$PROJECT_ROOT" worktree add "$worktree_path" "$branch_name"; then
            log_error "Failed to add worktree for existing branch '$branch_name'."
            return 1
        fi
    else
        if ! git -C "$PROJECT_ROOT" worktree add -b "$branch_name" "$worktree_path" "$base_branch_ref"; then
            log_error "Failed to create worktree branch '$branch_name' from '$base_branch_ref'."
            return 1
        fi
    fi

    if [ "$no_env_copy" = false ]; then
        sync_env_files_to_worktree "$worktree_path"
    else
        log_info "Skipping env sync (--no-env-copy)"
    fi

    if [ "$install_deps" = true ]; then
        install_detected_dependencies "$worktree_path"
    fi

    if [ "$start_docker" = true ]; then
        start_docker_services "$worktree_path"
    fi

    log_success "Worktree created: $worktree_path"
    log_info "Next step: cd $worktree_path"
}

cmd_finish() {
    local branch_name=""
    local should_switch=false
    local should_remove=true
    local no_env_sync_back=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --switch)
                should_switch=true
                shift
                ;;
            --no-remove)
                should_remove=false
                shift
                ;;
            --no-env-sync-back)
                no_env_sync_back=true
                shift
                ;;
            --help|-h)
                show_usage
                return 0
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name="$1"
                    shift
                else
                    log_error "Unknown argument: $1"
                    return 1
                fi
                ;;
        esac
    done

    if [ -z "$branch_name" ]; then
        log_error "Branch name is required"
        show_usage
        return 1
    fi

    local worktree_path
    worktree_path="$(get_worktree_path "$branch_name")"

    if [ ! -d "$worktree_path" ]; then
        log_error "Worktree not found at: $worktree_path"
        return 1
    fi

    if has_uncommitted_changes "$worktree_path"; then
        log_error "Worktree has uncommitted or untracked changes. Commit/stash first."
        return 1
    fi

    log_success "Worktree is clean for branch '$branch_name'"

    if [ "$no_env_sync_back" = false ]; then
        sync_env_files_from_worktree "$worktree_path"
    else
        log_info "Skipping env sync-back (--no-env-sync-back)"
    fi

    if [ "$should_remove" = true ]; then
        git -C "$PROJECT_ROOT" worktree remove "$worktree_path"
        log_success "Removed worktree: $worktree_path"
    else
        log_info "Keeping worktree: $worktree_path"
    fi

    if [ "$should_switch" = true ]; then
        git -C "$PROJECT_ROOT" checkout "$branch_name"
        log_success "Switched main worktree to '$branch_name'"
    else
        log_info "Branch available in main worktree: $branch_name"
        log_info "To switch: git -C \"$PROJECT_ROOT\" checkout \"$branch_name\""
    fi
}

cmd_list() {
    log_info "Active worktrees:"
    git -C "$PROJECT_ROOT" worktree list
}

cmd_remove() {
    local branch_name=""
    local force=false
    local no_env_sync_back=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --force)
                force=true
                shift
                ;;
            --no-env-sync-back)
                no_env_sync_back=true
                shift
                ;;
            --help|-h)
                show_usage
                return 0
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name="$1"
                    shift
                else
                    log_error "Unknown argument: $1"
                    return 1
                fi
                ;;
        esac
    done

    if [ -z "$branch_name" ]; then
        log_error "Branch name is required"
        show_usage
        return 1
    fi

    local worktree_path
    worktree_path="$(get_worktree_path "$branch_name")"

    if [ ! -d "$worktree_path" ]; then
        log_error "Worktree not found at: $worktree_path"
        return 1
    fi

    if [ "$force" = false ] && has_uncommitted_changes "$worktree_path"; then
        log_error "Worktree has uncommitted/untracked changes. Use --force to remove anyway."
        return 1
    fi

    if [ "$no_env_sync_back" = false ]; then
        sync_env_files_from_worktree "$worktree_path"
    else
        log_info "Skipping env sync-back (--no-env-sync-back)"
    fi

    if [ "$force" = true ]; then
        git -C "$PROJECT_ROOT" worktree remove --force "$worktree_path"
    else
        git -C "$PROJECT_ROOT" worktree remove "$worktree_path"
    fi

    log_success "Removed worktree: $worktree_path"
    log_info "Branch still exists: $branch_name"
}

cmd_sync_env() {
    local branch_name="${1:-}"

    if [ -z "$branch_name" ]; then
        log_error "Branch name is required"
        show_usage
        return 1
    fi

    local worktree_path
    worktree_path="$(get_worktree_path "$branch_name")"

    if [ ! -d "$worktree_path" ]; then
        log_error "Worktree not found at: $worktree_path"
        return 1
    fi

    sync_env_files_to_worktree "$worktree_path"
    log_success "Environment sync complete for '$branch_name'"
}

main() {
    ensure_in_git_repo
    init_project_context

    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        create)
            cmd_create "$@"
            ;;
        finish)
            cmd_finish "$@"
            ;;
        list)
            cmd_list
            ;;
        remove)
            cmd_remove "$@"
            ;;
        sync-env)
            cmd_sync_env "$@"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
