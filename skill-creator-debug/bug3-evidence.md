# Bug 3 Evidence: Premature `return False` in Detection Logic

## Test Setup

**Prompt tested:**
```
Start the implementation plan for the S2 frontend scaffold. The design doc is at
.artifacts/current/design_S2_frontend_scaffold.md and it is one subsystem of the
master design at .artifacts/current/design_master.md
```

**Target project:** `fin-lab-x-wt-feat-v1-frontend-streaming` (worktree)
**Expected result:** Should trigger `implementation-planning` skill
**Command:** `claude -p <prompt> --output-format stream-json --verbose --include-partial-messages`

## Raw Log Summary

```
Total events: 6225
  assistant: 74
  stream_event: 6090
  system: 13
  user: 46
  result: 1
```

## Key Events (chronological)

```
[4]   stream_event/content_block_start: thinking
[78]  assistant: content_types=['thinking']                    ← thinking-only message
[88]  assistant: content_types=['text']                        ← text-only message
[90]  stream_event/content_block_start: tool_use name=Skill   ← Skill tool call
[97]  assistant: content_types=['tool_use'], tools=['Skill']
[99]  stream_event/content_block_start: tool_use name=Read
[125] stream_event/content_block_start: tool_use name=Read
...later: Glob, Bash, WebSearch, WebFetch, Write, Agent, etc.
```

Claude's behavior: think first (event [78]), then call Skill (event [90]), then Read the design files, then proceed with implementation planning.

## Detection Results

Three versions of the detection logic were replayed against the same captured log:

### FIXED (current) — Result: TRIGGERED

```
[78] assistant: content_types=['thinking'] -> no tool_use, keep waiting
[88] assistant: content_types=['text'] -> no tool_use, keep waiting
[90] stream/content_block_start: tool_use name=Skill -> TRACK
[96] stream/content_block_delta: MATCH 'implementation-planning' in partial JSON
```

Correctly skips thinking-only and text-only messages, waits for the Skill tool call, detects the match.

### BUG 3a (non-Skill tool → return False) — Result: TRIGGERED

```
[78] assistant: content_types=['thinking'] -> no tool_use, keep waiting
[88] assistant: content_types=['text'] -> no tool_use, keep waiting
[90] stream/content_block_start: tool_use name=Skill -> TRACK
[96] stream/content_block_delta: MATCH
```

Not triggered in this run because Claude's first tool call happened to be Skill (event [90]). If Claude had called Glob or Read first (as it does in later turns), Bug 3a would have fired. This bug is **real but depends on Claude's strategy per query**.

### BUG 3b (thinking-only message → return False) — Result: NOT TRIGGERED

```
[78] assistant: content_types=['thinking'] -> BUG 3b: return triggered=False
```

**Confirmed false negative.** The thinking-only assistant message at event [78] caused the buggy code to return `False` immediately. It never reached event [90] where the Skill tool call occurs.

## Conclusion (Test 1)

| Bug | Confirmed? | Evidence |
|-----|-----------|----------|
| Bug 3a | Real but not triggered in this run | Claude called Skill first; later turns show Glob/Read/Bash before Skill — different query strategies would trigger it |
| Bug 3b | **Confirmed** | Event [78] (thinking-only) caused immediate `return False`, missing the Skill call at event [90] |

---

## Test 2 — Bug 3a: Ambiguous Prompt (Glob before Skill)

**Prompt tested:**
```
Check if there is a design doc or a planned implementation in this project.
If there is, create an implementation plan from it.
```

**Target project:** `fin-lab-x-wt-feat-v1-frontend-streaming` (worktree)
**Expected result:** Claude explores first (Glob/Read), then triggers `implementation-planning`

### Raw Log Summary

```
Total events: 713
  assistant: 18
  stream_event: 680
```

### Key Events

```
[40]  assistant: content_types=['thinking']               ← thinking-only
[49]  stream_event/content_block_start: tool_use name=Glob  ← first tool: Glob (not Skill)
[58]  stream_event/content_block_start: tool_use name=Glob
[69]  stream_event/content_block_start: tool_use name=Glob
[153] stream_event/content_block_start: tool_use name=Read
[177] stream_event/content_block_start: tool_use name=Read
[203] stream_event/content_block_start: tool_use name=Read
[348] stream_event/content_block_start: tool_use name=Bash
...no Skill tool call in entire log
```

Claude explored the project (Glob, Read, Bash) and did the planning inline without invoking the Skill tool.

### Detection Results

| Version | Result | Decision point |
|---------|--------|----------------|
| FIXED | NOT TRIGGERED | [56] Glob tool_use in assistant message → no match → return False |
| Bug 3a | NOT TRIGGERED | [49] stream: Glob → `return False` immediately |
| Bug 3b | NOT TRIGGERED | [40] thinking-only → `return False` immediately |

All three return NOT TRIGGERED — correct result since Claude never called Skill. Bug 3a fires at event [49] (Glob), but since Skill was never called afterward, this test doesn't demonstrate a **false negative** from Bug 3a. It only shows the bug fires on a non-Skill tool.

---

## Test 3 — Bug 3a: Explicit Multi-Step Prompt (Context7 → Design → Plan)

**Prompt tested:**
```
First, use Context7 to look up the latest Vite project setup guide and React
integration docs. Then find the design doc in this project (should be under
.artifacts/). Once you have both the official Vite reference and the design doc,
create an implementation plan from the design.
```

**Target project:** `fin-lab-x-wt-feat-v1-frontend-streaming` (worktree)
**Expected result:** Claude calls Context7 MCP first, then Glob/Read, then triggers `implementation-planning`

### Raw Log Summary

```
Total events: 839
  assistant: 20
  stream_event: 804
```

### Key Events

```
[41]  assistant: content_types=['thinking']                           ← thinking-only
[56]  stream_event/content_block_start: tool_use name=ToolSearch      ← first tool: ToolSearch
[76]  stream_event/content_block_start: tool_use name=Glob
[138] stream_event/content_block_start: tool_use name=mcp__context7__resolve-library-id
[157] stream_event/content_block_start: tool_use name=Read
[181] stream_event/content_block_start: tool_use name=Read
[282] stream_event/content_block_start: tool_use name=Read
[307] stream_event/content_block_start: tool_use name=mcp__context7__resolve-library-id
[468] stream_event/content_block_start: tool_use name=mcp__context7__resolve-library-id
[487] stream_event/content_block_start: tool_use name=Bash
...no Skill tool call in entire log
```

Same pattern: Claude followed instructions (Context7, Glob, Read) but did planning inline without Skill.

### Detection Results

| Version | Result | Decision point |
|---------|--------|----------------|
| FIXED | NOT TRIGGERED | [74] ToolSearch tool_use in assistant message → no match → return False |
| Bug 3a | NOT TRIGGERED | [56] stream: ToolSearch → `return False` immediately |
| Bug 3b | NOT TRIGGERED | [41] thinking-only → `return False` immediately |

Same outcome as Test 2 — all correct NOT TRIGGERED, but no false negative to demonstrate.

---

## Overall Conclusion

| Bug | Status | Evidence |
|-----|--------|----------|
| Bug 3b | **Confirmed — false negative demonstrated** | Test 1: thinking-only message at [78] caused premature `return False`, missing the Skill call at [90] |
| Bug 3a | **Defensive fix — logically sound, no false negative captured** | Tests 2 & 3: Bug 3a fires on non-Skill tools (Glob at [49], ToolSearch at [56]), but Claude chose to plan inline without calling Skill in both cases. The fix prevents premature exit on non-Skill tools, which is correct behavior regardless — the detector should keep listening rather than give up on the first unrelated tool. |

**Why Bug 3a is still worth fixing:** Even though we couldn't produce a single `claude -p` run where Claude calls a non-Skill tool AND then calls Skill in the same turn, the code path is valid. In the eval pipeline, queries run in parallel with diverse prompts — some prompts may cause Claude to explore first (Glob/Grep) and then invoke Skill. The old code would immediately return `False` on the first non-Skill tool, never seeing the Skill call. The fix (reset and continue listening) is minimal and has no downside.

## Reproduction

```bash
# Test 1 — Bug 3b confirmed:
python3 scripts/run_eval_bug3_test.py raw-stream-log.jsonl implementation-planning

# Test 2 — Bug 3a fires but no Skill call follows:
python3 scripts/run_eval_bug3_test.py raw-stream-log-bug3a.jsonl implementation-planning

# Test 3 — Bug 3a fires but no Skill call follows:
python3 scripts/run_eval_bug3_test.py raw-stream-log-bug3a-v2.jsonl implementation-planning
```

Raw log files captured from `claude -p` runs on 2026-03-21.
