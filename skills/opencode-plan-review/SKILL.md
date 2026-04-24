---
name: th1nkful:opencode-plan-review
description: Antagonistic plan review via opencode (OpenAI) — gets a second opinion on a plan from a different model provider, then triages findings
---

# opencode-plan-review

Antagonistic plan review using the `opencode` CLI to run a different model provider (OpenAI by default) against the current plan. The goal is to surface blind spots Claude may have missed — architecture gaps, correctness risks, weak test strategy, plausible edge cases.

## Arguments

$ARGUMENTS

Arguments may include:
- A Linear issue URL (e.g. `https://linear.app/...`) — optional context
- A path to a plan file — optional, otherwise use the plan from the current conversation
- A model override like `model=openai/gpt-5` — optional
- Free-form extra context for the reviewer

None are required. If nothing is provided, review the plan currently in conversation context.

## Instructions

### Step 1: Gather context

Collect the inputs the reviewer needs:

1. **The plan itself.** In priority order:
   - A plan file path in `$ARGUMENTS` → read it
   - A plan already produced earlier in this conversation → use it verbatim
   - Otherwise: stop and ask the user where the plan is

2. **Linear issue context** (if a Linear URL is in `$ARGUMENTS`):
   - Use the Linear MCP (`mcp__claude_ai_Linear__get_issue`) to fetch the issue, description, and comments
   - Include title, description, acceptance criteria, and any linked documents in the reviewer's context
   - If no Linear URL is provided, skip — don't invent one

3. **Repo context.** The reviewer will run inside the current repo via `opencode`, so it has file access. No need to dump files into the prompt — just point it at the relevant paths the plan touches.

### Step 2: Build the review prompt

Write a single prompt for `opencode` with these sections:

```
You are an antagonistic plan reviewer. A different model (Claude) produced the plan below. Your job is to find blind spots: things Claude is likely to have missed, glossed over, or gotten subtly wrong.

Be opinionated but not pedantic. Focus on:
- Architecture: is the shape of this solution right? Are there simpler or more robust alternatives?
- Correctness: will this actually work? What assumptions are load-bearing and unverified?
- Test strategy: does the plan test real behavior, or is it planning to mock the thing under test? Call out test coverage that would pass while the feature is broken.
- Plausible edge cases: concurrency, failure modes, partial state, unusual inputs, migration/rollback.

Rules:
- Skip style nitpicks and cosmetic suggestions.
- If you have open questions that would change your review, list them explicitly under "Open Questions" — do not guess.
- If something looks fine, say so briefly and move on. Don't pad.
- Ground every concern in a specific part of the plan or codebase. No generic advice.

Output format:
## Concerns
- [severity: high|medium|low] concern, with the specific plan section or file it applies to, and why it matters

## Open Questions
- questions the user needs to answer before you can finish the review

## What looks right
- one or two lines, only if genuinely notable

---

[LINEAR CONTEXT — if available]
[THE PLAN]
[ANY EXTRA CONTEXT FROM $ARGUMENTS]

Relevant repo paths to inspect: [list paths the plan touches]
```

### Step 3: Run opencode

Write the prompt to a temp file and run opencode with it. Use a model override if the user specified one, otherwise let opencode use its default.

```bash
PROMPT_FILE=$(mktemp -t opencode-plan-review.XXXXXX)
# write prompt to $PROMPT_FILE
opencode run --agent build --dangerously-skip-permissions < "$PROMPT_FILE"
```

Pass `-m <model>` if the user specified one (e.g. `-m openai/gpt-5`). If opencode fails (not installed, no auth), report the error and suggest `opencode auth login` or `brew install opencode`.

Capture the full output.

### Step 4: Triage

Read the reviewer's output. For each concern and open question, decide:

- **Valid** — genuine issue, worth acting on
- **Uncertain** — plausible but needs user judgment or more context; defer to the user
- **Invalid** — false positive, based on a misread of the plan, or a nitpick

Be honest. If the reviewer caught something real, say so even if it means reworking the plan. If it's wrong, say why.

### Step 5: Present results

Output in this shape:

**Valid concerns** — each with a one-line explanation of why it's real and what part of the plan it changes.

**Open questions from the reviewer** — surface these to the user verbatim or lightly paraphrased. Do not answer them on the user's behalf.

**Uncertain** — where you can't tell without user input. State the tradeoff.

**Dismissed** — one line each, why.

### Step 6: Apply obvious fixes to the plan, surface the rest

Split valid concerns into two buckets:

- **Auto-apply to the plan** — narrow, obvious corrections where there is exactly one sensible fix. Examples: a missing step the plan clearly needs, a factual error about the codebase, a test-strategy fix where the plan proposed mocking the thing under test, a missed edge case that slots into an existing step.
- **Needs user input** — anything that changes the plan's direction, scope, architecture, or tradeoffs. Anything where a reasonable person could pick a different approach. Anything that affects what gets built vs deferred.

For the auto-apply bucket: if the plan lives in a file, edit it and list the changes as "Applied to plan:" with a one-line summary each. If the plan lives only in conversation, produce an updated version and mark the applied changes inline. If you start applying a change and realise it's less obvious than it looked, stop and move it to the needs-input bucket.

For the needs-input bucket: list each as a proposed change with the tradeoff and what decision you need from the user.

### Important

- Default to surfacing, not applying. Directional or architectural changes always go to the user.
- If unsure whether a concern applies, defer to the user rather than dismissing it.
- If the reviewer found nothing substantive, say so clearly — don't manufacture findings.
- Keep each triage entry to 1–2 sentences.
