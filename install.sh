#!/usr/bin/env bash
set -euo pipefail

# Install/update claude-skills into ~/.claude/commands/
# Usage: ./install.sh [skill-name]
#   No arguments: installs all skills
#   With argument: installs only the named skill

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
DEST="$HOME/.claude/commands"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "Error: skills/ directory not found at $SKILLS_SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

install_skill() {
  local src="$1"
  local name
  name="$(basename "$src")"
  cp "$src" "$DEST/$name"
  echo "  installed: $name"
}

if [ $# -gt 0 ]; then
  # Install specific skill(s)
  for skill in "$@"; do
    src="$SKILLS_SRC/${skill}.md"
    if [ ! -f "$src" ]; then
      echo "Error: skill '$skill' not found at $src" >&2
      exit 1
    fi
    install_skill "$src"
  done
else
  # Install all skills
  count=0
  for src in "$SKILLS_SRC"/*.md; do
    [ -f "$src" ] || continue
    install_skill "$src"
    count=$((count + 1))
  done
  if [ "$count" -eq 0 ]; then
    echo "No skills found in $SKILLS_SRC"
    exit 1
  fi
  echo "Installed $count skill(s) to $DEST"
fi
