# claude-skills

Custom slash commands for Claude Code.

## Skills

- [`/th1nkful:catchup`](skills/catchup/SKILL.md) — Git branch context recovery and plan kickoff
- [`/th1nkful:assess`](skills/assess/SKILL.md) — Code review using focused lenses (simplicity, correctness, patterns, tests)
- [`/th1nkful:resolve-pr-feedback`](skills/resolve-pr-feedback/SKILL.md) — Triage and fix unresolved PR review comments
- [`/th1nkful:codex-review`](skills/codex-review/SKILL.md) — Antagonistic code review via `codex review`, with triage of findings
- [`/th1nkful:resolve-rebase-conflicts`](skills/resolve-rebase-conflicts/SKILL.md) — Safely resolve git rebase conflicts with stacked diff awareness

## Installation

```bash
# Install all skills
./install.sh

# Install a specific skill
./install.sh codex-review
```

Skills are installed to `~/.claude/skills/` where Claude Code picks them up as global slash commands.

Re-run `./install.sh` after pulling updates.
