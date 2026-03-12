# claude-skills

Custom slash commands for Claude Code.

## Skills

- [`/codex-review`](skills/codex-review.md) — Antagonistic code review via `codex review`, with triage of findings

## Installation

```bash
# Install all skills
./install.sh

# Install a specific skill
./install.sh codex-review
```

Skills are copied to `~/.claude/commands/` where Claude Code picks them up as global slash commands.

Re-run `./install.sh` after pulling updates.
