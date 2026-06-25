# pipeit-skill

> Claude Code skill for [`@pipeit/core`](https://github.com/stevesarmiento/pipeit) —
> type-safe Solana transaction building on `@solana/kit`.

A skill addon for the [Solana AI Kit](https://github.com/solanabr/solana-ai-kit) that turns
any coding agent into an expert `@pipeit/core` builder.

---

## What this skill covers

- `TransactionBuilder` — single transactions with auto-blockhash, retry, priority fees, CU estimation, ALTs
- `createFlow` — multi-step workflows where instructions depend on previous results
- `executePlan` — Kit instruction-plans integration for optimal automatic batching
- Execution strategies — Jito bundles, parallel RPC, direct TPU submission
- `@pipeit/core/server` — Next.js TPU proxy API route
- Error handling — typed errors, type guards, `diagnoseError()`

---

## Problem it solves

`@pipeit/core` is a full-featured transaction builder built on `@solana/kit` (web3.js 2.x).
Agents working without this skill regularly make mistakes:

- Using `setFeePayer(address)` instead of `setFeePayerSigner(signer)` before executing
- Forgetting to set compute budget for DeFi instructions
- Not handling `isBlockhashExpiredError` — causing silent failures under load
- Importing `@pipeit/core/server` in browser code
- Using the `'ultra'` preset without `@pipeit/fastlane`
- Mixing up when to use `TransactionBuilder` vs `createFlow` vs `executePlan`

This skill gives agents the full accurate API surface, decision trees, and rules
to avoid all of these.

---

## Installation

### Option 1 — npx (recommended)

Run the interactive installer without adding a dependency to your project:

```bash
npx pipeit-skill
```

The installer will:

- Ask whether to install globally (`~/.claude/skills/`) or into the current project (`./.claude/skills/`)
- Register the skill in your `CLAUDE.md` automatically
- Print next steps

### Option 2 — Install globally via npm

```bash
npm install -g pipeit-skill
pipeit-skill
```

Run `pipeit-skill` once after installing to trigger the setup wizard.

### Option 3 — Into the Solana AI Kit (git submodule)

```bash
cd your-solana-ai-kit
git submodule add https://github.com/ahmadou5/pipeit-skill .claude/skills/pipeit
```

Then reference it in your root `CLAUDE.md`:

```markdown
## Skills

- `.claude/skills/pipeit/skill/SKILL.md` — @pipeit/core transaction building
```

---

## Manual CLAUDE.md registration

If you skipped the installer or are managing `CLAUDE.md` yourself, add this entry:

```markdown
## Skills

- `~/.claude/skills/pipeit-skill/skill/SKILL.md` — @pipeit/core transaction building
```

Adjust the path to match where the skill was installed.

---

## Structure

```
pipeit-skill/
├── CLAUDE.md                       # Claude Code registration
├── README.md
├── package.json
├── LICENSE
│
├── bin/
│   └── install.js                  # npx entry point (setup wizard)
│
├── skill/
│   ├── SKILL.md                    # Entry point + routing table
│   ├── setup.md                    # Installation + RPC + signer setup
│   ├── transaction-builder.md      # TransactionBuilder full API
│   ├── flow.md                     # createFlow multi-step API
│   ├── plans.md                    # executePlan + Kit instruction-plans
│   ├── execution-strategies.md     # Jito, parallel, TPU, presets
│   ├── server.md                   # @pipeit/core/server, tpuHandler
│   ├── error-handling.md           # Errors, type guards, diagnoseError
│   └── resources.md                # Links, changelog, versions
│
├── agents/
│   └── pipeit-engineer.md          # Specialized agent
│
├── commands/
│   ├── build-tx.md                 # /build-tx scaffold command
│   └── debug-tx.md                 # /debug-tx diagnostic command
│
└── rules/
    └── pipeit-rules.md             # Coding rules enforced by skill
```

---

## Stack covered

| Layer               | Package                          |
| ------------------- | -------------------------------- |
| Transaction builder | `@pipeit/core` v0.2.7            |
| Solana JS SDK       | `@solana/kit` v6.x (web3.js 2.x) |
| Instruction plans   | `@solana/instruction-plans`      |
| Compute budget      | `@solana-program/compute-budget` |
| TPU (optional)      | `@pipeit/fastlane`               |

---

## License

MIT
