---
name: address-comments
description: >-
  Find and process @cmt and @qst directives in the specified files/folders (or the working
  directory): @cmt implements the requested code change, @qst answers the inline question. Use
  when the user asks to address comments or process inline annotation directives, or invokes
  /address-comments.
disable-model-invocation: true
---

# Address Comment Directives

Scan for `@cmt` and `@qst` directives, then process each one according to its type. Directives are standalone annotations written directly in the file (e.g., `@cmt add error handling`), not necessarily inside code comments.

## Finding directives

Use Grep to search for `@cmt` or `@qst`. If the user specifies particular files or folders, search **only** those paths. When no scope is given, default to the working directory.

For each match, read the surrounding code (at least 20 lines above and below) to build full context — the directive's meaning depends heavily on the code around it.

## Directive types

### `@cmt` — Code change request

The directive describes a code change to implement. Process:

1. Read surrounding code to understand the context and intent
2. Implement the requested change based on the instruction and context
3. Remove the `@cmt` directive entirely after implementing

**Example:**
```typescript
@cmt add input validation for negative numbers
function calculateSquareRoot(n: number): number {
  return Math.sqrt(n);
}
```
After processing:
```typescript
function calculateSquareRoot(n: number): number {
  if (n < 0) {
    throw new RangeError('Cannot calculate square root of a negative number');
  }
  return Math.sqrt(n);
}
```

### `@qst` — Inline question

The directive asks a question about the code. Instead of modifying code, answer the question in the chat response. Process:

1. Read surrounding code to understand what the question is about
2. Answer the question in the chat, clearly stating:
   - The file path and line number where the question was found
   - The relevant code snippet being discussed
   - A thorough answer to the question
3. Remove the `@qst` directive after answering

**Chat response language:** Answer in bilingual form — keep all terminology and code references in English, but write the rest of the explanation in Traditional Chinese (Taiwan usage).

**Example — directive in code:**
```python
@qst why does this use a defaultdict instead of a regular dict?
from collections import defaultdict
word_counts = defaultdict(int)
```

**Example — chat response:**
> **Question at `src/parser.py:42`:**
> ```python
> from collections import defaultdict
> word_counts = defaultdict(int)
> ```
> _Why does this use a defaultdict instead of a regular dict?_
>
> `defaultdict(int)` 會自動將不存在的 key 初始化為 `0`，因此可以直接寫 `word_counts[word] += 1`，不需要先檢查 key 是否存在。如果用一般的 dict，就需要寫成 `word_counts[word] = word_counts.get(word, 0) + 1` 或使用 `setdefault`。`defaultdict` 的寫法更簡潔，也是 counting pattern 中比較 idiomatic 的做法。

## Processing order

1. Collect all directives first (both `@cmt` and `@qst`)
2. Process all `@qst` directives first — answer every question in the chat before making any code changes. This way the user sees all answers upfront.
3. Then process all `@cmt` directives — implement each code change and remove the directive.

## Cross-reference ripple check

After processing all directives in a file, scan the entire file for stale references to anything that was changed. If a directive renamed, restructured, or removed something, other parts of the same file — and potentially other dependent files — may reference the old version. Update all stale references in the same pass.

**Discovery resolution cascade:** When a directive resolves a pending item (e.g., a「需確認」item in a briefing's discovery section), the resolution can change scope, architecture, or constraints. After resolving, explicitly check each other section of the document for consistency with the resolution — the impact is not limited to find-and-replace of identifiers, but may require content-level adjustments to downstream sections.

---

## Artifact sync

The briefing (`artifacts/current/briefing.md`) is the human review surface for the entire development plan. When directives modify the briefing, changes must propagate back to the source artifacts so the coding agent executes the updated intent.

After all directives are processed, if `artifacts/current/briefing.md` was among the processed files **and its content was actually modified** (by any directive type — `@cmt` or `@qst`), invoke `apply-briefing-update` via the Skill tool.

Skip sync silently when:
- No processed file is the briefing artifact
- The briefing file was not actually modified (e.g., only `@qst` tags were removed but no content changed)

## Edge cases

- If a `@cmt` instruction is ambiguous, use the surrounding code structure, naming conventions, and project patterns to infer the most reasonable interpretation.
- If a `@qst` question requires broader project context (e.g., "why is this architecture used?"), explore related files before answering.
