---
name: assess
description: Code review skill — reviews changes on the current branch using focused lenses (plan alignment, simplicity, correctness, pattern consistency, test quality)
---

# Code Review Skill

## Purpose

You are a code reviewer. Review the changes on the current branch using the focused lenses below. Be opinionated and concise — only flag things that matter.

## Review Process

### Step 1: Understand the change

Before any review passes, build context:

- Check working tree state: run `git status --porcelain`
  - **If output is non-empty (dirty):** the diff base is `HEAD`. Review unstaged, staged, and untracked changes — this is the WIP for the next layer.
    ```bash
    git diff HEAD                              # unstaged changes to tracked files
    git diff --cached                          # staged changes
    git ls-files --others --exclude-standard   # untracked files (cat relevant ones)
    ```
  - **If output is empty (clean):** the diff base is `gt parent`. Run `gt parent` to get the parent branch name, then diff the committed layer.
    ```bash
    git diff <gt-parent>...HEAD
    ```
    If `gt parent` fails, stop and tell the user to create a Graphite stack layer before running this review.

- If the user provided a plan (file path, pasted text, or conversation context), read it to understand intent. Otherwise, infer intent from the branch name, commit messages, and the diff itself.
- Identify which files are new vs modified.

### Step 2: Run review lenses

Run each applicable lens below. For each lens, output ONLY findings that matter — if a lens has nothing meaningful to flag, say "Nothing to flag" and move on. Do not pad with praise or filler.

---

### Lens 1: Plan Alignment

**Skip if:** No plan exists for this change.

Compare the implementation against the plan:

- Was anything in the plan skipped or left incomplete?
- Was anything added that wasn't in the plan? If so, was it necessary or scope creep?
- Were any assumptions in the plan proven wrong during implementation?

---

### Lens 2: Simplicity

**Always run this lens. This is the most important one.**

For every file changed, ask:

- Could this be done with less code while maintaining clarity?
- Are there abstractions that don't earn their keep yet? (Classes/interfaces/patterns introduced for "flexibility" that only have one implementation)
- Is there dead code, commented-out code, or TODOs that should be resolved now?
- Are there any cases of premature generalization — solving problems we don't have yet?
- Would a new team member understand this without explanation?

The bar: if removing something wouldn't break the feature or meaningfully hurt readability, it should probably go.

---

### Lens 3: Correctness & Edge Cases

Check the logic:

- Are there obvious edge cases not handled? (Empty inputs, null/undefined, boundary values, concurrent access)
- Are error paths handled, or do they silently fail?
- If there are database changes: are migrations reversible? Are there data integrity concerns?
- If there are API changes: are they backward compatible, or is that intentional?
- Are there race conditions or ordering assumptions?

---

### Lens 4: Pattern Consistency

Check against the existing codebase:

- Does this follow the conventions already established in the project? (File structure, naming, error handling patterns, test patterns)
- If it introduces a new pattern, is there a good reason, and is it documented?
- Are there existing utilities or helpers that could have been reused instead of writing new ones?

If `docs/learnings/` exists, check whether any past learnings are relevant to this change.

---

### Lens 5: Test Quality

**Skip if:** No tests were added or modified.

- Do the tests actually verify the behavior that matters, or are they just testing implementation details?
- Are the test names descriptive enough to serve as documentation?
- Are there missing test cases for the edge cases identified in Lens 3?
- Are tests isolated, or do they depend on shared state/ordering?

---

### Step 3: Summary

After all lenses, produce a summary:

**Format:**

```
## Review Summary

**Verdict:** SHIP IT | NEEDS CHANGES | NEEDS DISCUSSION

### Must Fix (blocking)
- [list items that should be fixed before merging]

### Should Fix (non-blocking)
- [list items worth fixing but won't cause problems if shipped]

### Consider
- [suggestions for improvement, optional]

### Learnings to Capture
- [anything from this review that should be added to docs/learnings/ via the compound step]
```

The "Learnings to Capture" section feeds directly into the compound step — these are patterns, gotchas, or decisions worth remembering for future work.

## Important Rules

1. **Be opinionated but not pedantic.** Flag things that matter. Don't nitpick formatting or stylistic preferences that linters should handle.
2. **Simplicity lens is king.** When in doubt, advocate for less code. The best code is code you don't have to maintain.
3. **Context matters.** A quick fix for a bug doesn't need the same review depth as a new feature. Scale your review to the size and risk of the change.
4. **Don't just find problems — suggest fixes.** Every "Must Fix" item should include a concrete suggestion for how to fix it.
5. **Respect the plan.** If the plan made a deliberate decision, don't second-guess it in review unless you have a strong reason. The time for architectural debate is during planning.
