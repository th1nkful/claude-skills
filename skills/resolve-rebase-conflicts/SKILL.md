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

**In a rebase, `ours` and `theirs` are the opposite of what intuition says.** Git checks out the branch you are rebasing *onto* and replays your commits on top of it. So `HEAD` is upstream, not you:

```
<<<<<<< HEAD (or ours)
  → UPSTREAM — the branch you are rebasing onto
=======
  → YOUR commit being replayed — the work at risk
>>>>>>> <commit-hash> (<your commit subject>)
```

**`theirs` = your branch's changes. That is almost always what you want to preserve.**

Verification tip: the text after `>>>>>>>` is the hash and subject line of *your own* commit. If you recognise that commit message as your work, you have the sides the right way round. Confirm with:

```bash
git log -1 --format='%h %s' $(cat .git/rebase-merge/stopped-sha 2>/dev/null)
```

Always read the actual code to decide, never the label alone.

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

Then find out **why upstream changed it** — do not guess from the diff alone:

```bash
# The upstream commits that touched this file since your branch diverged
git log --oneline ORIG_HEAD...HEAD -- <file>

# Full message of a specific upstream commit — look for a "why", a ticket ref, a PR number
git log -1 --format=%B <commit>

# The PR that introduced it, if gh is available
gh pr list --search "<commit-hash>" --state merged
```

If the upstream change was a deliberate fix or refactor, the commit message usually says so. That intent decides which strategy in Step 3 applies.

Ask:
- What did **my branch** change in this file?
- What did **upstream** change, and **why**?
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

#### Hard rule: resolve, do not invent

Every line in the resolution must come from one side or the other. A conflict resolution is **not** a licence to write new behaviour that neither side had — no new abstraction to "unify" the two versions, no reworked function signature to make both fit, no compatibility shim invented on the spot. That produces code no reviewer ever approved and no test covers, hidden inside a rebase where nobody looks for it.

If the two sides genuinely cannot coexist without new code, that belongs in **When to Stop and Ask** below — not solved inline.

When sides are mutually exclusive and you must drop one, **say what you dropped**. Keep the version that matches the purpose of the rebase, then state plainly in your report: *"kept upstream's X, dropped my branch's Y because Z."* A silent choice between two valid options is indistinguishable from losing work by accident.

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
git rebase --continue    # or `st continue` in a stacked workflow
```

---

## Know What `st continue` Already Runs

`st continue` fires this repo's configured **`pre-continue`** lifecycle hooks before it resumes the restack. In most repos that already covers format, lint, and typecheck — so running them again yourself is wasted time, and it is the single most common way this skill gets run inefficiently.

**Check the hooks before validating anything by hand:**

```bash
st hooks
```

Read the `pre-continue` block. Whatever is listed there, **do not re-run** — `st continue` did it, and it aborts on failure, so a successful `st continue` is itself proof those checks passed.

A typical `pre-continue` block looks like this:

| Hook | Command | Re-run after `st continue`? |
|---|---|---|
| `format` | `make format && git add -u` | No — already applied and staged |
| `lint` | `make lint-ci` | No |
| `typecheck` | `make typecheck` | No |
| — | tests | **Yes** — not a `pre-continue` hook, so still your job |

The useful move is therefore the inverse of the usual instinct: skip the checks the hook ran, and run the ones it **didn't**. Tests are typically the gap, because they are too slow to put in a hook that fires once per commit in the stack.

If `st hooks` shows `pre-continue` as `Not set`, or the repo does not use `st`, then nothing was run for you — do the full sequence in the Post-Rebase Checklist yourself.

One caveat: hooks run once per paused commit, so a mid-stack pass does not prove the *final* stack state is clean. After the whole restack finishes, still do the end-to-end verification below.

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
| `git checkout --ours <file>` | **In a rebase this discards all of your branch's changes** to that file — `ours` is upstream. This is the shortcut that silently loses work |
| `git checkout --theirs <file>` | Takes your branch's version wholesale, discarding every upstream change to the file — safer for your work, but drops real upstream fixes |
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
```

**4. Validate — typecheck, then tests, then lint.** Skip whatever `pre-continue` already ran (see above); run the rest. In a repo whose hooks cover format/lint/typecheck, that means tests only:

```bash
make test 2>/dev/null || pnpm test 2>/dev/null || npm test 2>/dev/null || true
```

Outside a stacked workflow, or with no `pre-continue` hooks, run the full sequence in that order — typecheck first, because a type error is faster to surface than a test suite failing for the same reason.

**5. Only then force push** — `--force-with-lease`, never `--force`:

```bash
git push --force-with-lease
```
