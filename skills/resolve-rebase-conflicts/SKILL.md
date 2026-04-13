---
name: th1nkful:resolve-rebase-conflicts
description: Safely resolve git rebase conflicts — reads both sides, preserves real work, applies stacked diff awareness
user_invocable: true
---

# Git Rebase Conflict Resolution

## STOP AND READ THIS FIRST

Rebase conflict resolution is **high-risk**. Resolving a conflict the wrong way — especially by naively accepting "theirs" (i.e. whatever is in the base branch) — will silently discard real work. In a stacked diff workflow, that work is **gone** once the branch is force pushed.

**The number one rule: when in doubt, keep more code, not less.**

---

## Context Detection

Before touching any conflict, establish the full picture:

### 1. Are we in a stacked diff workflow?

```bash
# Check for st (Stackit)
which st 2>/dev/null

# Check if branch has a parent that is NOT main/master
git log --oneline origin/main..HEAD
```

If `st` is present, **assume stacking is in use** and apply stacked diff rules throughout.

### 2. What caused the rebase?

```bash
git status
git rebase --show-current-patch 2>/dev/null || true
cat .git/rebase-merge/head-name 2>/dev/null || cat .git/rebase-apply/head-name 2>/dev/null
```

### 3. What branch are we rebasing onto?

```bash
cat .git/rebase-merge/onto 2>/dev/null | xargs git name-rev --name-only 2>/dev/null
```

---

## Understanding the Conflict Sides

Git conflict markers mean:

```
<<<<<<< HEAD (or ours)
  → This is YOUR branch's code — the work being rebased
=======
  → This is the BASE (the branch you're rebasing onto)
>>>>>>> <commit-hash> (or theirs)
```

**"Ours" = your branch's changes. This is almost always what you want to preserve.**

> ⚠️ In a rebase (unlike a merge), the `ours`/`theirs` labels are **inverted** compared to what you might expect. `HEAD` during a rebase refers to the upstream commit being replayed onto — not your branch tip. Always verify by reading the actual code, not just the label.

---

## The Resolution Algorithm

Work through each conflicted file methodically. **Do not batch-resolve conflicts without reading each one.**

### Step 1: List all conflicts

```bash
git diff --name-only --diff-filter=U
```

### Step 2: For each conflicted file, read and understand BOTH sides

```bash
git diff HEAD -- <file>               # see full conflict diff
git show ORIG_HEAD:<file>             # what the file looked like before rebase started
git log --oneline ORIG_HEAD..HEAD -- <file>  # what your branch changed in this file
```

Ask:
- What did **my branch** change in this file?
- What did **upstream** change? Why?
- Are these changes **additive** (both can coexist) or **mutually exclusive**?

### Step 3: Apply the right strategy per conflict type

#### Type A: Additive (most common)
Both sides added different things. **Keep both.** Manually merge so neither set of changes is lost.

#### Type B: Upstream fixed something your branch also fixed
Read both fixes. Keep the **better** one, or reconcile if they fixed different aspects.

#### Type C: Upstream deleted something your branch modified
Check intent. If upstream deletion is intentional (e.g. refactor), adapt your change to the new structure. Do **not** silently drop your change.

#### Type D: Pure formatting/whitespace conflict
Accept upstream formatting, re-apply your logical change on top.

#### Type E: Your change is strictly additive (new function, new import, new test)
Your code almost certainly needs to be **kept**. Accept upstream's structural changes, then re-insert your additions.

### Step 4: Verify the resolution makes sense

After resolving each file:
```bash
# Confirm no leftover conflict markers
grep -n "<<<<<<\|=======\|>>>>>>" <file>

# Review your resolution
git diff --cached -- <file>
```

### Step 5: Stage and continue

```bash
git add <file>
# Only continue when ALL conflicts are resolved
git rebase --continue
```

---

## Stacked Diff Specific Rules

When using `st` with stacked branches:

1. **Identify which stack level is being rebased.** A conflict might come from a change introduced in a parent branch, not from main.

2. **Do not blindly accept upstream.** In a stack, "upstream" might be another feature branch that also has pending changes. Pulling it wholesale can drop work from the current branch.

3. **After resolving, check the diff of the whole stack:**
   ```bash
   git log --oneline origin/main..HEAD
   git diff origin/main..HEAD -- <file>
   ```
   Verify that all commits in the stack still contain the intended changes.

4. **Before any force push**, run:
   ```bash
   git diff origin/<branch>..HEAD
   ```
   Confirm the diff is **only additions/changes you expect** — not a net subtraction of real work.

---

## What NOT to Do

| Tempting shortcut | Why it's dangerous |
|---|---|
| `git checkout --theirs <file>` | Discards all of your branch's changes to that file |
| `git checkout --ours <file>` | Discards all upstream changes (also risky in a rebase due to label inversion) |
| Accepting one side without reading both | May silently drop logic |
| `git rebase --skip` or `st skip` | Drops your entire commit — **never use during conflict resolution**; only valid if a commit was genuinely empty before the rebase started, and even then, confirm with the user first |
| `git rebase --abort` then retry without understanding the conflict | Doesn't fix the root cause |

---

## When to Stop and Ask

Stop and surface uncertainty to the user if:

- A conflict involves **business logic** you don't fully understand
- Resolving seems to require **deleting a substantial block of code** from your branch
- The file has **4+ conflict regions** and the intent is unclear
- You're not confident which side introduced which change

Say: *"This conflict in `<file>` involves [describe]. I want to confirm the right resolution before proceeding — here are the two sides: [show]. Which should take precedence?"*

---

## Post-Rebase Checklist

After all conflicts are resolved and rebase completes:

```bash
# 1. Confirm clean state
git status

# 2. Review the full diff vs origin
git diff origin/<current-branch>

# 3. Check commit count is what you expect
git log --oneline origin/main..HEAD

# 4. Run tests if available
pnpm test 2>/dev/null || npm test 2>/dev/null || true

# 5. Only then force push — use --force-with-lease, never --force
git push --force-with-lease
```
