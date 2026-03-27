## Commit Message Convention

Format: `type(scope): description`

Types:
- `fork` — imported from a third-party skill source (e.g., Superpower)
- `create` — a new skill built from scratch
- `feat` — add a new capability or behavior to an existing skill
- `improve` — enhance quality, clarity, or structure (not a bug fix, not a new feature)
- `fix` — bug fix for an existing skill
- `prune` — trim or simplify parts of a skill (remove sections, reduce scope)
- `remove` — delete an entire skill
- `repo` — repo-level changes not tied to a specific skill (e.g., CLAUDE.md, shared config)

Scope:
- Single skill: use the skill's directory name (e.g., `session-handoff`, `skill-creator`)
- Multiple skills in one commit: use `multi`

Examples:
- `fork(multi): import 4 skills from Superpower plugin`
- `create(design-brainstorming): add design brainstorming skill`
- `feat(session-handoff): add two-stage overview/detail report flow`
- `fix(skill-creator): fix eval pipeline recall bug`
- `repo: update commit message convention`
