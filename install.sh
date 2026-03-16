#!/usr/bin/env bash
set -euo pipefail

# Install/update claude-skills into ~/.claude/skills/ (and ~/.claude/commands/ for legacy flat files)
# Usage: ./install.sh [skill-name]
#   No arguments: installs all skills
#   With argument: installs only the named skill

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"
COMMANDS_DEST="$HOME/.claude/commands"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "Error: skills/ directory not found at $SKILLS_SRC" >&2
  exit 1
fi

install_skill_dir() {
  local src_dir="$1"
  local name
  name="$(basename "$src_dir")"
  mkdir -p "$SKILLS_DEST/$name"
  cp "$src_dir/SKILL.md" "$SKILLS_DEST/$name/SKILL.md"
  echo "  installed skill: $name"
}

install_flat_command() {
  local src="$1"
  local name
  name="$(basename "$src")"
  mkdir -p "$COMMANDS_DEST"
  cp "$src" "$COMMANDS_DEST/$name"
  echo "  installed command: $name"
}

if [ $# -gt 0 ]; then
  for skill in "$@"; do
    if [ -d "$SKILLS_SRC/$skill" ] && [ -f "$SKILLS_SRC/$skill/SKILL.md" ]; then
      install_skill_dir "$SKILLS_SRC/$skill"
    elif [ -f "$SKILLS_SRC/${skill}.md" ]; then
      install_flat_command "$SKILLS_SRC/${skill}.md"
    else
      echo "Error: skill '$skill' not found in $SKILLS_SRC" >&2
      exit 1
    fi
  done
else
  count=0

  # Install skill directories (skills/<name>/SKILL.md)
  for src_dir in "$SKILLS_SRC"/*/; do
    [ -f "$src_dir/SKILL.md" ] || continue
    install_skill_dir "$src_dir"
    count=$((count + 1))
  done

  # Install flat command files (skills/<name>.md) — legacy fallback
  for src in "$SKILLS_SRC"/*.md; do
    [ -f "$src" ] || continue
    install_flat_command "$src"
    count=$((count + 1))
  done

  if [ "$count" -eq 0 ]; then
    echo "No skills found in $SKILLS_SRC"
    exit 1
  fi
  echo "Installed $count skill(s)"
fi
