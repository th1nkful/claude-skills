---
name: th1nkful:codex-review
description: Antagonistic code review using codex review — runs codex to review changes, then triages the output
---

# codex-review

Antagonistic code review using `codex review`. Runs codex to review changes, then triages the output.

## Arguments

$ARGUMENTS

## Instructions

You are running an antagonistic code review using `codex review`. Your job is to run the review, then critically assess each issue found.

### Step 1: Determine Review Mode

Based on the arguments, determine which review mode to use. The user may specify one of:

- **wip** — Review uncommitted changes: `codex review --uncommitted`
- **layer** — Review current layer against parent: `codex review --base $(gt parent)`
- **stack** — Review full stack against main: `codex review --base main`

If no mode is specified, default to **wip**.

Any additional text in the arguments beyond the mode keyword should be passed through to codex as extra context appended to the command.

### Step 2: Run the Review

Construct and execute the codex command:

- For **wip**: `codex review --uncommitted`
- For **layer**: First run `gt parent` to get the parent branch, then run `codex review --base <parent>`
- For **stack**: `codex review --base main`

If the user provided extra context after the mode keyword, append it to the codex command.

Run the command and capture the full output. If the command fails (e.g. codex not installed, gt not available for layer mode), report the error clearly and suggest alternatives.

### Step 3: Triage Each Issue

For each issue identified by codex, critically assess whether it is actually a valid concern. Consider:

- Is this a real bug or just a style preference?
- Does the reviewer have full context, or is it missing something?
- Is the suggestion actually an improvement, or would it introduce complexity?
- Does the issue apply to the actual code, or is it a false positive?

### Step 4: Present Results

Present the issues grouped into three categories:

**Valid Issues**
Issues that are genuine problems worth addressing. For each, explain briefly why it's valid.

**Uncertain**
Issues where the reviewer may have a point but more context is needed, or where it's debatable. Explain the tradeoff.

**Invalid / Noise**
Issues that are false positives, style nitpicks that don't matter, or suggestions that would make the code worse. Explain why you're dismissing them.

### Important

- Do NOT automatically fix any issues. Only assess and present them.
- Be honest — if codex found something real, say so, even if it's uncomfortable.
- If codex found nothing, say so clearly.
- Keep assessments concise. One or two sentences per issue is enough.
