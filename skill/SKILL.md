# Pipeit Skill

> Type-safe transaction building for Solana with `@pipeit/core`.
> Built on `@solana/kit` (web3.js 2.x). MIT licensed.

---

## What is Pipeit?

`@pipeit/core` is a transaction builder that wraps `@solana/kit` with:
- Auto-blockhash fetching, auto-retry, priority fees, compute unit estimation
- Multi-step transaction flows with automatic batching
- Kit instruction-plans integration
- Advanced execution: Jito bundles, parallel RPC, direct TPU

**Current version:** `0.2.7`
**Peer requirement:** `@solana/kit ^6.0.1`

---

## Routing Table

Load only the skill file you need. Do not load all files at once.

| Task | Load |
|------|------|
| Install, RPC setup, peer deps | [`setup.md`](./setup.md) |
| Single transaction — build, simulate, execute, export | [`transaction-builder.md`](./transaction-builder.md) |
| Multi-step flows, dependent steps, atomic groups | [`flow.md`](./flow.md) |
| Kit instruction-plans, parallel/sequential batching | [`plans.md`](./plans.md) |
| Jito bundles, parallel RPC, TPU, execution presets | [`execution-strategies.md`](./execution-strategies.md) |
| Next.js TPU API route, server-side TPU proxy | [`server.md`](./server.md) |
| Error types, diagnoseError, type guards | [`error-handling.md`](./error-handling.md) |

---

## Quick Decision Guide

**"I need to send one transaction"**
→ `TransactionBuilder` — see [`transaction-builder.md`](./transaction-builder.md)

**"My instructions depend on results from previous transactions"**
→ `createFlow()` — see [`flow.md`](./flow.md)

**"I know all my instructions upfront and want Kit to batch them optimally"**
→ `executePlan()` — see [`plans.md`](./plans.md)

**"I need MEV protection / faster landing / Jito"**
→ Execution strategies — see [`execution-strategies.md`](./execution-strategies.md)

**"I need TPU submission from a browser/Next.js app"**
→ Server handler — see [`server.md`](./server.md)

**"A transaction failed and I need to debug it"**
→ Error handling — see [`error-handling.md`](./error-handling.md)

---

## Core Mental Model

```
Instructions (from any Solana program SDK)
        │
        ▼
┌─────────────────────────────────────────────┐
│  TransactionBuilder / createFlow / executePlan │
│  ├── auto-blockhash                          │
│  ├── priority fees + CU estimation           │
│  ├── ALT compression                         │
│  └── retry logic                             │
└─────────────────────────────────────────────┘
        │
        ▼
Execution Strategy
  standard → RPC sendTransaction
  economical → Jito bundle
  fast → Jito + parallel RPC race
  ultra → TPU + Jito (requires @pipeit/fastlane)
```

Pipeit does NOT generate instructions. You get instructions from protocol SDKs
(e.g. `@solana-program/system`, Raydium SDK, Orca SDK, etc.) and pass them in.