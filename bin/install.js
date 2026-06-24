#!/usr/bin/env node

import fs from "fs";
import path from "path";
import os from "os";
import readline from "readline";

const SKILL_NAME = "pipeit";
const HOME_DIR = os.homedir();
const DEFAULT_INSTALL_DIR = path.join(
  HOME_DIR,
  ".claude",
  "skills",
  SKILL_NAME,
);

// Determine script location (files bundled inside npm package module)
const __dirname = path.dirname(new URL(import.meta.url).pathname);
const PACKAGE_ROOT = path.join(__dirname, "..");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

console.log("\n  🚀 Installing pipeit-skill for Claude Code via npm");
console.log("  ──────────────────────────────────────────────────\n");

// Handle non-interactive auto-yes flag (-y)
const isNonInteractive = process.argv.includes("-y");

function askQuestion(query) {
  return new Promise((resolve) => rl.question(query, resolve));
}

async function main() {
  let installDir = DEFAULT_INSTALL_DIR;

  if (!isNonInteractive) {
    const input = await askQuestion(
      `Where would you like to install the skill?\n📂 Path [Default: ${DEFAULT_INSTALL_DIR}]: `,
    );
    if (input.trim()) {
      // Handle ~ substitution manually in JS
      installDir = input.replace(/^~/, HOME_DIR);
    }
  }

  // 1. Create directory safely
  fs.mkdirSync(installDir, { recursive: true });

  // 2. Copy the directories
  const directoriesToCopy = ["skill", "agents", "commands", "rules"];
  directoriesToCopy.forEach((dir) => {
    const sourcePath = path.join(PACKAGE_ROOT, dir);
    const destPath = path.join(installDir, dir);

    if (fs.existsSync(sourcePath)) {
      fs.cpSync(sourcePath, destPath, { recursive: true });
    }
  });
  console.log(`  ✓ Skill files installed to: ${installDir}`);

  // 3. Handle CLAUDE.md mapping
  const claudeDir = path.join(HOME_DIR, ".claude");
  fs.mkdirSync(claudeDir, { recursive: true });
  const targetClaudeMd = path.join(claudeDir, "CLAUDE.md");

  let shouldAppend = true;
  if (fs.existsSync(targetClaudeMd)) {
    const content = fs.readFileSync(targetClaudeMd, "utf8");

    // Prevent duplicate setups
    if (content.includes("## Pipeit Skill")) {
      console.log(
        "  ℹ Pipeit Skill reference already exists in CLAUDE.md. Skipping.",
      );
      shouldAppend = false;
    } else if (!isNonInteractive) {
      const confirm = await askQuestion(
        `  ❓ Found existing CLAUDE.md. Append pipeit-skill integration rules? [Y/n]: `,
      );
      if (confirm.toLowerCase().startsWith("n")) {
        shouldAppend = false;
      }
    }
  }

  if (shouldAppend) {
    const appendText = `\n\n## Pipeit Skill\nSkill for \`@pipeit/core\` transaction building.\nEntry point: \`${path.join(installDir, "skill", "SKILL.md")}\`\n`;
    fs.appendFileSync(targetClaudeMd, appendText);
    console.log(`  ✓ Appended configuration to ${targetClaudeMd}`);
  }

  console.log("\n  🎉 Done! The pipeit-skill is ready for Claude Code.");
  console.log("  ───────────────────────────────────────────────────");
  console.log(`  Entry point:  ${path.join(installDir, "skill", "SKILL.md")}`);
  console.log(
    `  Agent:        ${path.join(installDir, "agents", "pipeit-engineer.md")}\n`,
  );

  rl.close();
}

main().catch((err) => {
  console.error(`  ✗ Error during installation: ${err.message}`);
  rl.close();
  process.exit(1);
});
