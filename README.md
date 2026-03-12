# claude-skills

Custom slash commands for Claude Code.

## Skills

### `/codex-review`

Antagonistic code review powered by `codex review`. Runs a review, then triages each finding as valid, uncertain, or noise.

**Modes:**

- `/codex-review wip` — Review uncommitted changes (default if no mode given)
- `/codex-review layer` — Review current layer against parent (`gt parent`)
- `/codex-review stack` — Review full stack against `main`

**Extra context:** Append any text after the mode to pass through to codex:

```
/codex-review wip focus on error handling in the auth module
```

## Installation

```bash
# Install all skills
./install.sh

# Install a specific skill
./install.sh codex-review
```

Skills are copied to `~/.claude/commands/` where Claude Code picks them up as global slash commands.

Re-run `./install.sh` after pulling updates.
