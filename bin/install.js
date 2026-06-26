#!/usr/bin/env node

import fs from "fs";
import path from "path";
import os from "os";
import readline from "readline";

const SKILL_NAME = "pipeit";
const HOME_DIR = os.homedir();

// Agent config map — where each agent looks for skills/context
const AGENTS = {
  1: {
    name: "Claude Code",
    configDir: path.join(HOME_DIR, ".claude"),
    skillsDir: path.join(HOME_DIR, ".claude", "skills", SKILL_NAME),
    configFile: "CLAUDE.md",
    sectionHeader: "## Pipeit Skill",
    entryLabel: "Entry point",
  },
  2: {
    name: "Codex",
    configDir: path.join(HOME_DIR, ".agents"),
    skillsDir: path.join(HOME_DIR, ".agents", "skills", SKILL_NAME),
    configFile: "AGENTS.md",
    sectionHeader: "## Pipeit Skill",
    entryLabel: "Entry point",
  },
  3: {
    name: "Cursor",
    configDir: path.join(process.cwd(), ".cursor"),
    skillsDir: path.join(process.cwd(), ".cursor", "skills", SKILL_NAME),
    configFile: "rules", // Cursor uses .cursor/rules (a directory)
    sectionHeader: null, // writes a standalone file instead
    entryLabel: "Rule file",
  },
  4: {
    name: "Other / Custom",
    configDir: null, // will be asked interactively
    skillsDir: null,
    configFile: null,
    sectionHeader: null,
    entryLabel: "Entry point",
  },
};

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const PACKAGE_ROOT = path.join(__dirname, "..");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const isNonInteractive = process.argv.includes("-y");

function ask(query) {
  return new Promise((resolve) => rl.question(query, resolve));
}

function copySkillFiles(installDir) {
  fs.mkdirSync(installDir, { recursive: true });
  for (const dir of ["skill", "agents", "commands", "rules"]) {
    const src = path.join(PACKAGE_ROOT, dir);
    const dest = path.join(installDir, dir);
    if (fs.existsSync(src)) {
      fs.cpSync(src, dest, { recursive: true });
    }
  }
  console.log(`  ✓ Skill files installed to: ${installDir}`);
}

function registerClaudeStyle(agent, installDir) {
  // Used by Claude Code and Codex — append a section to a .md config file
  const configPath = path.join(agent.configDir, agent.configFile);
  fs.mkdirSync(agent.configDir, { recursive: true });

  const entryPoint = path.join(installDir, "skill", "SKILL.md");

  if (fs.existsSync(configPath)) {
    const content = fs.readFileSync(configPath, "utf8");
    if (content.includes(agent.sectionHeader)) {
      console.log(
        `  ℹ  ${agent.sectionHeader} already exists in ${agent.configFile}. Skipping.`,
      );
      return;
    }
  }

  const block = `\n\n${agent.sectionHeader}\nSkill for \`@pipeit/core\` transaction building.\n${agent.entryLabel}: \`${entryPoint}\`\n`;
  fs.appendFileSync(configPath, block);
  console.log(`  ✓ Appended configuration to ${configPath}`);
}

function registerCursor(agent, installDir) {
  // Cursor reads individual rule files from .cursor/rules/
  const rulesDir = path.join(agent.configDir, "rules");
  fs.mkdirSync(rulesDir, { recursive: true });

  const ruleFile = path.join(rulesDir, "pipeit-skill.md");
  const entryPoint = path.join(installDir, "skill", "SKILL.md");

  if (fs.existsSync(ruleFile)) {
    console.log(`  ℹ  ${ruleFile} already exists. Skipping.`);
    return;
  }

  const content = `# Pipeit Skill\nSkill for \`@pipeit/core\` transaction building.\nEntry point: \`${entryPoint}\`\n`;
  fs.writeFileSync(ruleFile, content);
  console.log(`  ✓ Wrote Cursor rule to ${ruleFile}`);
}

async function main() {
  console.log("\n  🚀 Installing pipeit-skill");
  console.log("  ──────────────────────────────────────────────────\n");

  // Step 1 — pick agent
  let agentKey = 1; // default: Claude Code
  if (!isNonInteractive) {
    console.log("  Which agent are you installing for?\n");
    for (const [key, a] of Object.entries(AGENTS)) {
      console.log(`    ${key}) ${a.name}`);
    }
    const input = await ask("\n  Choice [1]: ");
    agentKey = parseInt(input.trim() || "1", 10);
    if (!AGENTS[agentKey]) {
      console.error("  ✗ Invalid choice.");
      rl.close();
      process.exit(1);
    }
  }

  const agent = { ...AGENTS[agentKey] };

  // Step 2 — resolve custom paths for "Other" choice
  if (agentKey === 4) {
    const customConfig = await ask("  Config directory (e.g. ~/.myagent): ");
    agent.configDir = customConfig.replace(/^~/, HOME_DIR);
    agent.skillsDir = path.join(agent.configDir, "skills", SKILL_NAME);

    const customFile = await ask("  Config filename (e.g. AGENT.md): ");
    agent.configFile = customFile.trim() || "AGENT.md";
    agent.sectionHeader = "## Pipeit Skill";
  }

  // Step 3 — confirm or override install path
  let installDir = agent.skillsDir;
  if (!isNonInteractive) {
    const input = await ask(`\n  Install skill files to [${installDir}]: `);
    if (input.trim()) installDir = input.replace(/^~/, HOME_DIR);
  }

  // Step 4 — copy files
  copySkillFiles(installDir);

  // Step 5 — register with agent config
  if (agentKey === 3) {
    registerCursor(agent, installDir);
  } else {
    registerClaudeStyle(agent, installDir);
  }

  // Step 6 — done
  const entryPoint = path.join(installDir, "skill", "SKILL.md");
  console.log(`\n  🎉 Done! pipeit-skill is ready for ${agent.name}.`);
  console.log("  ─────────────────────────────────────────────────────");
  console.log(`  Entry point:  ${entryPoint}`);
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
