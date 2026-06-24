#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="pipeit"
DEFAULT_INSTALL_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  pipeit-skill installer"
echo "  ────────────────────────────────────"
echo ""

# Non-interactive mode
NON_INTERACTIVE=false
for arg in "$@"; do
  [[ "$arg" == "-y" ]] && NON_INTERACTIVE=true
done

# Install location
INSTALL_DIR="$DEFAULT_INSTALL_DIR/$SKILL_NAME"

if [[ "$NON_INTERACTIVE" == false ]]; then
  read -r -p "Install to [$INSTALL_DIR]: " input
  [[ -n "$input" ]] && INSTALL_DIR="$input"
fi

# Create target directory
mkdir -p "$INSTALL_DIR"

# Copy skill files
cp -r "$SCRIPT_DIR/skill" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/agents" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/commands" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/rules" "$INSTALL_DIR/"

echo "  ✓ Skill files installed to $INSTALL_DIR"

# Copy CLAUDE.md
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

if [[ -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
  echo ""
  echo "  Found existing $CLAUDE_DIR/CLAUDE.md"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    read -r -p "  Append pipeit-skill reference? [Y/n]: " confirm
    confirm="${confirm:-Y}"
  else
    confirm="Y"
  fi

  if [[ "$confirm" =~ ^[Yy] ]]; then
    cat >> "$CLAUDE_DIR/CLAUDE.md" << EOF

## Pipeit Skill

Skill for \`@pipeit/core\` transaction building.
Entry point: \`$INSTALL_DIR/skill/SKILL.md\`
EOF
    echo "  ✓ Appended to $CLAUDE_DIR/CLAUDE.md"
  fi
else
  cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "  ✓ Copied CLAUDE.md to $CLAUDE_DIR/"
fi

echo ""
echo "  Done. The pipeit-skill is ready."
echo ""
echo "  Entry point: $INSTALL_DIR/skill/SKILL.md"
echo "  Agent:       $INSTALL_DIR/agents/pipeit-engineer.md"
echo "  Commands:    /build-tx, /debug-tx"
echo ""