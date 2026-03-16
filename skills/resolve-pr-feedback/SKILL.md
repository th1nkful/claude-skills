---
name: resolve-pr-feedback
description: Find unresolved PR feedback on the current branch's PR, identify legitimate issues, fix them, and verify precommits pass
user_invocable: true
---

# Resolve PR Feedback

Address unresolved review feedback on the current branch's PR: triage comments, fix legitimate issues, and verify everything passes.

## Execution Steps

### Step 1: Find the PR

1. Get the current branch name:
   ```bash
   git branch --show-current
   ```

2. Find the associated PR:
   ```bash
   gh pr view --json number,title,url,headRefName --jq '{number, title, url, headRefName}'
   ```
   This uses the current branch by default.

3. **If no PR is found**: STOP and ask the user: "No PR found for the current branch. Please provide a PR number or URL."

4. Confirm with the user: "Found PR #<number>: <title>. Proceeding to check for unresolved feedback."

### Step 2: Detect Repository Owner and Name

Determine the repository owner and name dynamically:

```bash
gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}'
```

Use the returned `owner` and `name` values for all subsequent API calls.

### Step 3: Fetch Unresolved Review Threads

Fetch all review threads and filter to unresolved ones using the GraphQL API:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            isOutdated
            path
            line
            comments(first: 50) {
              nodes {
                author { login }
                body
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -f owner=<OWNER> -f repo=<REPO> -F number=<PR_NUMBER>
```

Also fetch top-level PR comments (issue-style comments, which include bot comments):
```bash
gh api repos/<OWNER>/<REPO>/issues/<PR_NUMBER>/comments --jq '.[] | {author: .user.login, body: .body, created_at: .created_at}'
```

From the results:
- **Review threads**: Keep only threads where `isResolved: false`. Include `isOutdated` status for context (outdated threads may have already been addressed by a new push).
- **Issue comments**: Include all — these don't have a resolved state, so triage them in Step 4.

**If no unresolved threads and no issue comments with actionable feedback**: Report "No unresolved feedback found!" and stop.

### Step 4: Triage Feedback

For each piece of unresolved feedback, classify it:

#### Legitimate (should fix)
- Bug reports or correctness issues
- Missing error handling that could cause real problems
- Security concerns
- Violations of project conventions (check CLAUDE.md and relevant AGENTS.md)
- Performance issues with measurable impact
- Missing or broken tests for changed code
- Requests from automated reviewers (bots) that flag real issues (e.g., type errors, lint violations, missing migrations)

#### Noise (skip)
- Pure style/formatting preferences that linters handle
- "Consider" suggestions that don't improve correctness or clarity
- Outdated threads (`isOutdated: true`) where the referenced code has already changed — BUT read the comment carefully first; sometimes the feedback applies to the new code too
- Bot comments that are purely informational (e.g., deployment URLs, CI status)
- Suggestions that would over-engineer or add unnecessary complexity

#### Needs Discussion (flag to user)
- Architectural disagreements where there's no clear "right" answer
- Suggestions that require significant refactoring beyond the PR scope
- Feedback that contradicts the PR's stated intent or plan
- Ambiguous comments where the reviewer's intent is unclear

**Output a triage summary** before proceeding:

```
## Feedback Triage

### Will Fix (X items)
- [file:line] @reviewer: summary of issue → planned fix

### Skipping (X items)
- [file:line] @reviewer: summary → reason for skipping

### Needs Discussion (X items)
- [file:line] @reviewer: summary → why this needs user input
```

**STOP and wait for user confirmation** before proceeding. The user may reclassify items.

### Step 5: Fix Legitimate Issues

For each item in "Will Fix":

1. **Read the relevant code** — don't fix blindly. Understand the context around the flagged line.
2. **Make the fix** — keep changes minimal and focused. Don't refactor surrounding code.
3. **If the fix touches logic**: check if existing tests cover it. If not, add a targeted test.

Group related fixes when possible (e.g., if two comments flag the same pattern in different files, fix them together).

### Step 6: Verify

Run the checks appropriate to the files changed. At minimum:

1. **Format and lint** the affected apps (per CLAUDE.md rules)
2. **Type check** the affected apps
3. **Run relevant tests** for the changed code

If any check fails, fix the issue before proceeding. Do NOT use `--no-verify` or skip checks.

### Step 7: Summary

Provide a final summary:

```
## PR Feedback Resolution Complete

### Fixed (X items)
- [file:line] issue summary → what was done

### Skipped (X items)
- [file:line] reason

### Needs Discussion (X items)
- [file:line] summary (unchanged)

### Verification
- Format/Lint: PASS/FAIL
- Type Check: PASS/FAIL
- Tests: PASS/FAIL

### Files Changed
- list of modified files
```

## Important Rules

1. **Always triage before fixing.** Never blindly fix every comment — some feedback is noise. But always explain WHY you're skipping something.
2. **Minimal fixes only.** Address exactly what the reviewer asked for. Don't improve surrounding code, add docstrings, or refactor while you're at it.
3. **Respect project conventions.** Check the relevant AGENTS.md for the area you're modifying. Follow established patterns.
4. **Don't argue with legitimate feedback.** If a reviewer flagged a real bug or convention violation, fix it. Save the "but actually" for the "Needs Discussion" category.
5. **Automated reviewer feedback matters.** Bot comments (linters, type checkers, security scanners) that flag real issues should be treated as legitimate. Bot comments that are purely informational can be skipped.
6. **Wait for user confirmation after triage.** The user may want to reclassify items before you start making changes.
