---
name: th1nkful:opencode-code-review
description: Antagonistic code review via opencode (OpenAI) — gets a second opinion on code changes from a different model provider, then triages findings
---

# opencode-code-review

Antagonistic code review using the `opencode` CLI to run a different model provider (OpenAI by default) against the current diff. The goal is to surface blind spots Claude may have missed — architectural mistakes, correctness bugs, test coverage that doesn't test real behavior, plausible edge cases.

Complements `th1nkful:codex-review` — same intent, different reviewer model.

## Arguments

$ARGUMENTS

Arguments may include:
- A review mode: `wip` (uncommitted), `layer` (current layer vs `gt parent`), `stack` (vs `main`). Default: `wip`.
- A Linear issue URL — optional context
- A model override like `model=openai/gpt-5` — optional
- Free-form extra context for the reviewer

## Instructions

### Step 1: Determine diff scope

Based on the mode:
- **wip** — `git diff HEAD` plus staged plus untracked files (see `th1nkful:assess` for the pattern)
- **layer** — run `gt parent` to find the parent, then `git diff <parent>...HEAD`
- **stack** — `git diff main...HEAD`

Capture the diff. If there is no diff, stop and tell the user.

### Step 2: Gather Linear context (optional)

If a Linear URL is in `$ARGUMENTS`, fetch the issue via the Linear MCP (`mcp__claude_ai_Linear__get_issue`). Pull title, description, acceptance criteria, and linked docs. If no URL, skip.

### Step 3: Build the review prompt

Write a single prompt for `opencode` with these sections:

```
You are an antagonistic code reviewer. A different model (Claude) wrote this code. Your job is to find blind spots: things Claude is likely to have missed, glossed over, or gotten subtly wrong.

Be opinionated but not pedantic. Focus on:
- Architecture: is this the right shape? Misplaced abstractions, leaky boundaries, overreach, or things that will be painful to change later.
- Correctness: bugs, off-by-one, race conditions, incorrect error handling, unhandled failure modes, wrong assumptions about callers.
- Test quality: does the test actually exercise the production code path, or does it mock the thing under test into a tautology? Call out tests that would pass while the feature is broken. Missing coverage on the interesting branches.
- Plausible edge cases: concurrency, partial failure, unusual inputs, state that crosses process/request boundaries, migration/rollback, backwards compatibility.

Rules:
- Skip style nitpicks, formatting, and cosmetic naming.
- If you have open questions that would change your assessment, list them under "Open Questions" — do not guess.
- Ground every concern in a specific file and line. No generic advice.
- If something looks fine, say so briefly. Don't pad.

Output format:
## Concerns
- [severity: high|medium|low] file:line — concern and why it matters

## Open Questions
- questions the user needs to answer before you can finish the review

## What looks right
- one or two lines, only if genuinely notable

---

[LINEAR CONTEXT — if available]
[ANY EXTRA CONTEXT FROM $ARGUMENTS]

Review the following changes. Read surrounding files as needed to check assumptions.

[THE DIFF]
```

### Step 4: Run opencode

Write the prompt to a temp file and run opencode against it, in the repo root so it has file access:

```bash
PROMPT_FILE=$(mktemp -t opencode-code-review.XXXXXX)
# write prompt to $PROMPT_FILE
opencode run --agent build --dangerously-skip-permissions < "$PROMPT_FILE"
```

Pass `-m <model>` if the user specified one. If opencode fails (not installed, no auth), report the error and suggest `opencode auth login` or `brew install opencode`.

Capture the full output.

### Step 5: Triage

For each concern and open question, validate against the actual code:

- **Valid** — real issue. Reproduce the reasoning by pointing at the code.
- **Uncertain** — plausible but depends on context you don't have, or a judgment call the user should make. Defer to the user.
- **Invalid** — false positive, misread the code, or pure nitpick.

If you're unsure, default to uncertain — do not dismiss.

### Step 6: Present results

**Valid issues** — each with `file:line`, one-line explanation, and what the fix direction looks like.

**Open questions from the reviewer** — surface verbatim or lightly paraphrased. Do not answer them for the user.

**Uncertain** — state the tradeoff and what input from the user would resolve it.

**Dismissed** — one line each.

### Step 7: Apply obvious fixes, surface the rest

Split valid issues into two buckets:

- **Auto-apply** — narrow, local, mechanically obvious fixes where there is exactly one sensible correction. Examples: off-by-one, wrong variable used, missing null check on a path the reviewer correctly identified, a test that mocks the system under test and can be rewritten to hit the real code, a clearly missing branch in error handling.
- **Needs user input** — anything that touches architecture, public API shape, naming that ripples through callers, test strategy changes beyond a single test, anything where a reasonable person could pick a different fix, or anything that changes direction from what was planned.

For the auto-apply bucket: make the edits, then list them in the final output as "Applied:" with `file:line` and a one-line summary each. If you start applying a fix and realise it's less obvious than it looked, stop and move it to the needs-input bucket.

For the needs-input bucket: list each as a proposal with the tradeoff and what decision you need from the user.

### Important

- Default to surfacing, not applying. If there is any doubt about the right fix, it goes to the user.
- Never auto-apply architectural or directional changes, even if the reviewer is confident.
- If unsure whether a concern is valid at all, surface it as uncertain rather than dismissing it.
- If the reviewer found nothing substantive, say so — don't invent findings.
- Keep each triage entry to 1–2 sentences.
