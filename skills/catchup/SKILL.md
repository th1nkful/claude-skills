---
name: th1nkful:catchup
description: >
  Use this skill immediately and without hesitation whenever the user runs /catchup,
  with or without additional text. This skill serves two modes: (1) pure context
  recovery — "catch up", "get up to speed", "what were we working on", "resume
  context", "re-orient yourself", "read the changed files"; and (2) plan kickoff —
  "/catchup here is problem a, b, c; here is change x, y, z" where the user
  describes problems or changes in natural language and wants Claude to resolve
  those to actual files and immediately begin planning. In plan kickoff mode, skip
  the catch-up summary entirely and go straight into a concrete implementation plan
  using the resolved file context. Trigger even if the user just pastes /catchup
  with no other words.
---

# /catchup — Git Branch Context Recovery + Plan Kickoff

## Purpose

Restore working context after a fresh session or compaction by reading all files
changed in the current git branch. When the user provides problems or changes
alongside `/catchup`, skip the summary and go straight into planning.

---

## Step 0 — Detect mode

Before doing anything else, check whether the user included text after `/catchup`.

- **Context-only** (`/catchup` with nothing after it): run the full workflow and
  produce the catch-up summary.
- **Plan kickoff** (`/catchup <description of problems/changes>`): run the file
  discovery and reading steps silently, use the description to resolve which files
  are most relevant, then skip the summary and jump straight into a plan. The user
  does not need a recap — they know what they're working on. They want a plan.

---

## Step 1 — Discover changed files

**Priority order — stop at the first source that yields files:**

#### A. Uncommitted changes (always check first)

```bash
git diff --name-only          # unstaged
git diff --cached --name-only # staged
```

If either returns files, use that combined set — this is the active working surface.

#### B. Stacked diff — diff vs. Graphite stack parent (clean working tree)

```bash
gt parent 2>/dev/null
```

If `gt parent` succeeds, diff against the returned branch:

```bash
git diff <gt-parent-branch>..HEAD --name-only
```

This isolates exactly the commits in the current stack entry.

#### C. Fallback — diff vs. main/master

```bash
git diff main..HEAD --name-only 2>/dev/null || git diff master..HEAD --name-only
```

Deduplicate all paths. Note in any output which source was used.

---

## Step 2 — Get branch name and recent commits

```bash
git rev-parse --abbrev-ref HEAD
git log --oneline -10
```

---

## Step 3 — Read changed files

For each file in the list:
- Use `view` to read full contents
- Skip: binaries, images, compiled assets, lock files (`package-lock.json`,
  `pnpm-lock.yaml`, `poetry.lock`, `uv.lock`), generated dirs (`dist/`, `build/`,
  `.next/`, `__pycache__/`)

If **more than 30 files**, prioritise:
1. Files touched by the most recent commit
2. Files whose names/paths match keywords from the user's description (plan kickoff mode)
3. Source files over tests; core logic over config

Note how many files were skipped.

---

## Step 4 — Resolve user description to files (plan kickoff mode only)

When the user has provided a description of problems or changes, parse it loosely:

- Extract nouns, module names, feature names, error descriptions, and file hints
  (even vague ones like "the autocomplete stuff" or "the DSL parser")
- Match these against the file list and the content you've read
- Build a mental map of: **which files are the epicentre of this task**

You don't need to be exhaustive — you need to be accurate about where the work lives.
If something in the description doesn't obviously map to a file, note it and make
your best inference rather than asking. If the description references files outside
the changed set, read those too.

---

## Step 5 — Output

### Context-only mode → Catch-up summary

```
## Catch-up summary

**Branch:** <branch-name>
**Source:** <uncommitted changes | vs. stack parent `<branch>` | vs. main>
**Changed files (<N> total):** <comma-separated list>

**What's in progress:**
<2–4 sentences describing the work arc, inferred from file contents>

**Key areas touched:**
- <file or module>: <one-line description of what changed>
- ...

**Likely next steps** (based on code state):
- <inferred TODO or in-progress item>
- ...

Ready to continue. What would you like to work on?
```

### Plan kickoff mode → Skip summary, go straight to the plan

Do not produce a catch-up summary. The user knows the context — they just gave it
to you. Instead:

1. State in one sentence which files you're treating as the epicentre (so they can
   correct you fast if you're wrong)
2. Produce a concrete, file-anchored implementation plan:
   - Break the work into clear phases or steps
   - Reference specific files, functions, or types by name
   - Flag any ambiguities or risks you spotted in the code
   - Keep it tight — this is a senior engineer; no padding

Do not ask clarifying questions before producing the plan unless something is
genuinely unresolvable. Bias toward making a reasonable assumption and stating it.

---

## Edge cases

| Situation | Behaviour |
|---|---|
| Not in a git repo | Say so; offer to read files the user specifies manually |
| Clean working tree, gt parent works | Use `git diff <parent>..HEAD`; note the stack parent |
| Clean working tree, gt parent fails | Fall back to main/master; note this |
| Truly nothing changed anywhere | Say so; offer to read files from the last N commits |
| Very large files (>500 lines) | Read them; focus on changed sections via `git diff` if helpful |
| Merge conflicts present | Flag immediately — highest priority context |
| Monorepo with unrelated changes | Group by package/workspace |
| Description maps to files outside the changed set | Read those files too — changed set is a hint, not a constraint |

---

## Principles

- **In plan kickoff mode, the plan is the product.** Don't warm up with a summary,
  don't narrate your file-reading process — just deliver the plan.
- **Lead with intent, not inventory.** "We're mid-way through the autocomplete
  integration" beats "14 files were changed."
- **Be a compass, not a mirror.** Infer next steps from the code state; don't just
  reflect back what the user said.
- **Call out blockers.** TODOs, stubs, failing tests, half-implemented branches —
  surface them.
- **Match the register.** Senior engineer, technical terms fine, no hand-holding.
