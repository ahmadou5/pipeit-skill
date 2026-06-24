#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="pipeit"
DEFAULT_INSTALL_DIR="$HOME/.claude/skills/$SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Formatting Helpers
info() { echo -e "  \033[34mℹ\033[0m $*"; }
success() { echo -e "  \033[32m✓\033[0m $*"; }
error() { echo -e "  \033[31m✗\033[0m $*" >&2; }

echo ""
echo "  🚀 Installing pipeit-skill for Claude Code"
echo "  ──────────────────────────────────────────"
echo ""

# Parse flags
NON_INTERACTIVE=false
for arg in "$@"; do
  [[ "$arg" == "-y" || "$arg" == "--yes" ]] && NON_INTERACTIVE=true
done

# Smart Target Directory Selection
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

if [[ "$NON_INTERACTIVE" == false ]]; then
  # Show the default choice clearly so they can just press Enter
  echo "Where would you like to install the skill?"
  read -r -p "📂 Path [Default: $DEFAULT_INSTALL_DIR]: " input
  
  if [[ -n "$input" ]]; then
    # Expand ~ if the user typed it manually
    INSTALL_DIR="${input/#\~/$HOME}"
  fi
fi

# Ensure absolute pathing
if [[ "$INSTALL_DIR" != /* ]]; then
  INSTALL_DIR="$(pwd)/$INSTALL_DIR"
fi

# Create target directory safely
mkdir -p "$INSTALL_DIR"

# Verify source files exist before copying
for dir in skill agents commands rules; do
  if [[ -d "$SCRIPT_DIR/$dir" ]]; then
    cp -r "$SCRIPT_DIR/$dir" "$INSTALL_DIR/"
  else
    info "Skipping missing source directory: $dir"
  fi
done

success "Skill files installed to: $INSTALL_DIR"

# CLAUDE.md Configuration Handling
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
TARGET_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

if [[ -f "$TARGET_CLAUDE_MD" ]]; then
  echo ""
  info "Found existing configuration at $TARGET_CLAUDE_MD"
  
  if [[ "$NON_INTERACTIVE" == false ]]; then
    read -r -p "  ❓ Append pipeit-skill integration rules? [Y/n]: " confirm
    confirm="${confirm:-Y}"
  else
    confirm="Y"
  fi

  if [[ "$confirm" =~ ^[Yy] ]]; then
    # Prevent duplicate appends if script is run twice
    if grep -q "## Pipeit Skill" "$TARGET_CLAUDE_MD"; then
       info "Pipeit Skill reference already exists in CLAUDE.md. Skipping append."
    else
      cat >> "$TARGET_CLAUDE_MD" << EOF

## Pipeit Skill
Skill for \`@pipeit/core\` transaction building.
Entry point: \`$INSTALL_DIR/skill/SKILL.md\`
EOF
      success "Appended configuration to $TARGET_CLAUDE_MD"
    fi
  fi
else
  if [[ -f "$SCRIPT_DIR/CLAUDE.md" ]]; then
    cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_CLAUDE_MD"
    success "Created brand new CLAUDE.md at $TARGET_CLAUDE_MD"
  else
    error "Source CLAUDE.md file missing from installation package."
    exit 1
  fi
fi

echo ""
echo "  🎉 Done! The pipeit-skill is ready for Claude Code."
echo "  ───────────────────────────────────────────────────"
echo "  Entry point:  $INSTALL_DIR/skill/SKILL.md"
echo "  Agent:        $INSTALL_DIR/agents/pipeit-engineer.md"
echo "  Commands:     /build-tx, /debug-tx"
echo ""