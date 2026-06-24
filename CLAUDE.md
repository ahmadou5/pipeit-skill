# Pipeit Skill

This project uses the **pipeit-skill** for Claude Code.

## Skill location

Skills are in `.claude/skills/pipeit/skill/`.

## When to use this skill

Load `skill/SKILL.md` whenever the task involves:

- `@pipeit/core` or `TransactionBuilder`
- `createFlow` for multi-step Solana transactions
- `executePlan` with Kit instruction-plans
- Jito bundles, parallel RPC, or TPU transaction submission
- `@pipeit/core/server` or Next.js TPU API routes
- Debugging failed Solana transactions built with pipeit

## Skill entry point

```
skill/SKILL.md
```

The entry point routes to focused sub-skill files. Load only the relevant one.

## Agent

The `pipeit-engineer` agent in `agents/pipeit-engineer.md` is specialized for
all pipeit and Solana Kit transaction tasks.

## Commands

- `/build-tx` — scaffold a new transaction
- `/debug-tx` — diagnose a failed transaction
