#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  pipeit-skill — custom installer"
echo "  ────────────────────────────────────"
echo ""

# Step 1: Choose install location
echo "  Where should the skill be installed?"
echo "  1) Personal (~/.claude/skills/pipeit)  — available in all projects"
echo "  2) Project  (./.claude/skills/pipeit)  — this project only"
echo "  3) Custom path"
echo ""
read -r -p "  Choice [1]: " location_choice
location_choice="${location_choice:-1}"

case "$location_choice" in
  1) INSTALL_DIR="$HOME/.claude/skills/pipeit" ;;
  2) INSTALL_DIR="$(pwd)/.claude/skills/pipeit" ;;
  3)
    read -r -p "  Path: " custom_path
    INSTALL_DIR="$custom_path/pipeit"
    ;;
  *) INSTALL_DIR="$HOME/.claude/skills/pipeit" ;;
esac

# Step 2: Create and copy skill
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/skill" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/agents" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/commands" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/rules" "$INSTALL_DIR/"

echo "  ✓ Skill installed to $INSTALL_DIR"

# Step 3: CLAUDE.md placement
echo ""
echo "  Where should CLAUDE.md be placed?"
echo "  1) ~/.claude/CLAUDE.md          (personal, all projects)"
echo "  2) ./.claude/CLAUDE.md          (this project)"
echo "  3) ./CLAUDE.md                  (project root)"
echo "  4) Skip"
echo ""
read -r -p "  Choice [1]: " claude_choice
claude_choice="${claude_choice:-1}"

case "$claude_choice" in
  1) CLAUDE_TARGET="$HOME/.claude/CLAUDE.md" ;;
  2) CLAUDE_TARGET="$(pwd)/.claude/CLAUDE.md" ;;
  3) CLAUDE_TARGET="$(pwd)/CLAUDE.md" ;;
  4) CLAUDE_TARGET="" ;;
  *) CLAUDE_TARGET="$HOME/.claude/CLAUDE.md" ;;
esac

if [[ -n "$CLAUDE_TARGET" ]]; then
  mkdir -p "$(dirname "$CLAUDE_TARGET")"
  if [[ -f "$CLAUDE_TARGET" ]]; then
    read -r -p "  $CLAUDE_TARGET exists — append pipeit reference? [Y/n]: " append
    append="${append:-Y}"
    if [[ "$append" =~ ^[Yy] ]]; then
      cat >> "$CLAUDE_TARGET" << EOF

## Pipeit Skill

Skill for \`@pipeit/core\` transaction building on Solana.
Entry point: \`$INSTALL_DIR/skill/SKILL.md\`
EOF
      echo "  ✓ Appended to $CLAUDE_TARGET"
    fi
  else
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_TARGET"
    echo "  ✓ Created $CLAUDE_TARGET"
  fi
fi

echo ""
echo "  ────────────────────────────────────"
echo "  Installation complete!"
echo ""
echo "  Skill:    $INSTALL_DIR/skill/SKILL.md"
echo "  Agent:    $INSTALL_DIR/agents/pipeit-engineer.md"
echo "  Commands: /build-tx, /debug-tx"
echo ""