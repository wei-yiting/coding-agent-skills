---
name: project-understanding
description: Rehearse a repo's development story for a job interview — reconstruct architecture, decisions, and trade-offs from git history, PRs, and design artifacts; coach the user through active-recall rehearsal; produce a written recap (STAR + technical deep-dive) as markdown rendered to HTML. Use when the user wants to prepare to explain their development experience on a repo, feature, PR, or worktree to an interviewer ("帶我複習這個專案", "interview prep for this repo", "我要能講出這個架構的取捨"). Not for code-quality review (code-review) or resuming work state (dev-standup).
---

# Repo Interview Prep

Rehearse the user's own development work with them until they can explain it fluently to an interviewer. Deliverables: a guided **rehearsal** conversation, then a written recap document they re-read before the interview.

Core premise: the user *did* this work (often with AI agents doing much of the typing), but may no longer remember the why. Reconstruct the why from evidence, hand it back, and make sure they can say it in their own words. The success criterion is a **defensible** story — one that survives interviewer follow-up probing — so truthfulness and the user's actual understanding are the product; the document is only the memory aid.

## Language

Match the user's conversation language (default: 台灣繁體中文, technical terms in English). Ask early whether the interview itself is in English — if so, write the recap's talking points and STAR summaries in English; the rehearsal conversation stays in the user's language.

## Step 1 — Scope

If the user names a target (feature, module, PR number, branch, worktree), go straight to Step 2 for that target.

Otherwise run a quick repo survey (`references/evidence-gathering.md` § Survey) and present 3–6 candidate topics — the stories this repo can actually support. Good candidates are places where a decision was made: a subsystem with several design iterations, a revert-then-redo, a performance fix, a migration. One line each: what it is + why it makes a good interview story.

Also ask what kind of interview this is (system design vs behavioral shifts the emphasis); default to mixed STAR + technical depth.

Done when: the user has picked the story/stories and you know the interview type and language.

## Step 2 — Gather evidence

Follow `references/evidence-gathering.md`. Sources, in reading order: PR descriptions and review threads (`gh`) → design artifacts (`artifacts/`, ADRs, docs) → git history shape (reverts, refactor waves, merge boundaries) → the code as it stands now. Review threads are the densest source of why — they record objections and responses. The current code matters because interviewers ask "how does it work today", not just "how did it evolve". Use Explore subagents for broad sweeps; read the load-bearing PRs and files yourself.

**Provenance discipline.** Tag every claim you will later assert:

- ✅ **證據確鑿** — stated in a PR, design doc, commit message, or visible in code.
- ❓ **推測** — your inference about motivation or trade-off. Inferences are valuable (often exactly right), but each one must be confirmed by the user in Step 4 before it enters the final document — the user must walk into the interview repeating confirmed facts, not your guesses.

Done when: every fact you plan to use carries a ✅ or ❓ tag.

## Step 3 — Draft the narrative

Build a draft recap per `references/narrative-frameworks.md`:

- One **STAR skeleton** per story, each line traceable to evidence.
- A **technical deep-dive annex** per story: current architecture (Mermaid), key decisions with alternatives-considered and why-rejected, hard problems and their resolutions.
- **Likely follow-up questions** per story, derived from the actual trade-offs and weak points (not generic lists).

Gaps only the user can fill (business impact numbers, team context, what alternatives felt like at the time) become explicit questions for Step 4. The draft is your script for the rehearsal — the user sees it as conversation, and reads the polished document only at Step 5.

Done when: each story has a STAR skeleton, an annex, follow-up questions, and a list of user-only gaps.

## Step 4 — Rehearsal

The heart of the skill. Walk through the material story by story using **active recall**: the user explains first, you fill in after.

Rhythm per story:

1. Set the scene in 2–3 sentences (Situation/Task), then have the user tell the Action/Result as if answering an interviewer. When showing architecture, render Mermaid as an image (via `render-mermaid-in-session` if available).
2. Against the evidence: fill gaps, correct inaccuracies, supply the vocabulary they were reaching for. Where they nailed it, one sentence of confirmation and move on.
3. Confirm every ❓: 「我從 PR #42 的討論推測當時是為了避免 X，對嗎？」 Their answer becomes the authoritative version.
4. Throw 1–2 follow-up questions and let them try.
5. **⚠ Weak spots**: anywhere they stumbled, guessed wrong, or said 「我不知道為什麼」 — record it. Finding these now instead of in the interview is the point of rehearsing, so log them matter-of-factly.

Also harvest: the user's own phrasings (their words beat yours in an interview), numbers and outcomes only they know, context that never reached the repo.

Keep turns short and interactive — one story at a time. If the user opts to skip rehearsal and take the document directly, deliver it with the ❓ items still marked unconfirmed.

Done when: every ❓ is resolved, every story survived at least one follow-up attempt, and all ⚠ weak spots are logged.

## Step 5 — Write the recap document

Produce the final document per `references/narrative-frameworks.md` § Recap document, incorporating what rehearsal surfaced: confirmed facts, the user's own phrasings, and the ⚠ weak-spot list at the top — that list is what they cram before the interview.

Write the markdown source to `~/interview-prep/<repo-name>/<topic-slug>.md` (personal prep notes live outside the repo), then render it to HTML at the same path with `.html` — the HTML is the review surface the user reads *and annotates* before the interview. It must have a **text-selection comment panel**: select any passage → attach a note; notes persist across reloads and export as JSON. Comments are the user's self-flagged weak spots — when they return with an exported comments file, treat each comment as a ⚠ item and start rehearsal there.

Use the `htmlify` skill when available (it already provides TOC, rendered Mermaid, and selection-commenting); otherwise build the page yourself per `references/html-recap-template.md`. Either way: Mermaid rendered as diagrams (a raw ```mermaid code block on the page is a failure) and the ⚠ cram list visually prominent at the top. Tell the user both paths and open the HTML if the platform allows.

Done when: both the .md source and the .html render are saved, the HTML shows diagrams as diagrams, the comment panel works (add + persist + export), every ❓ is either resolved or explicitly marked unconfirmed, and the user knows the paths.

## Principles

- **Truth over polish.** A modest true story is defensible; an embellished one collapses under probing. "We tried X and it was fine" stays exactly that strong.
- **Bias time toward rehearsal.** The user's understanding is the product; the document is the by-product.
- **Depth over breadth.** Two stories defensible three follow-ups deep beat six the user can only open. Recommend narrowing when scope is large.
- **Agent-written code is presumed-weak.** Where history shows large agent-generated changes, the user shipped code they may never have internalized — spend extra rehearsal time there.
