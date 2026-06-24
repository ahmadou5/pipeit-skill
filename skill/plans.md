# Plans API

For when you know all instructions upfront and want Kit's transaction planner
to batch them optimally across multiple transactions automatically.

Pipeit re-exports all of `@solana/instruction-plans` and adds `executePlan()` as
a convenience wrapper that integrates with the standard pipeit config pattern.

---

## When to use Plans vs Flow vs TransactionBuilder

| Situation                                                                | Use                             |
| ------------------------------------------------------------------------ | ------------------------------- |
| Single transaction, known instructions                                   | `TransactionBuilder`            |
| Instructions depend on previous tx results                               | `createFlow`                    |
| All instructions known upfront, may span multiple txs, want Kit to batch | `executePlan`                   |
| Complex parallel + sequential batching logic                             | `executePlan` with nested plans |

---

## executePlan

```typescript
import { sequentialInstructionPlan, executePlan } from "@pipeit/core";

const plan = sequentialInstructionPlan([ix1, ix2, ix3, ix4, ix5]);

const result = await executePlan(plan, {
  rpc,
  rpcSubscriptions,
  signer,
  commitment: "confirmed", // optional, default 'confirmed'
});
```

Kit's planner automatically splits instructions across multiple transactions
if they don't fit in one.

---

## executePlan config

```typescript
// Without ALTs (standard)
await executePlan(plan, {
  rpc,
  rpcSubscriptions,
  signer,
  commitment?: 'processed' | 'confirmed' | 'finalized',
  abortSignal?: AbortSignal,
});

// With ALT addresses (auto-fetched — requires GetMultipleAccountsApi on rpc)
await executePlan(plan, {
  rpc,  // must include GetMultipleAccountsApi
  rpcSubscriptions,
  signer,
  lookupTableAddresses: [address('ALT1...'), address('ALT2...')],
});

// With pre-fetched ALT data (no extra RPC requirement)
await executePlan(plan, {
  rpc,
  rpcSubscriptions,
  signer,
  addressesByLookupTable: {
    [altAddress]: [addr1, addr2, addr3],
  },
});
```

---

## Plan types

### Sequential

Instructions execute in order. Kit batches consecutive instructions into transactions
where possible. If a batch exceeds tx size, it's split into separate transactions.

```typescript
import { sequentialInstructionPlan } from "@pipeit/core";

const plan = sequentialInstructionPlan([ix1, ix2, ix3]);
```

### Parallel

Instructions that can execute in any order. Kit may batch them or send in parallel.

```typescript
import { parallelInstructionPlan } from "@pipeit/core";

const plan = parallelInstructionPlan([depositA, depositB, depositC]);
```

### Non-divisible sequential

A group that MUST execute in a single transaction (atomic). If it doesn't fit, throws.

```typescript
import { nonDivisibleSequentialInstructionPlan } from "@pipeit/core";

const atomicGroup = nonDivisibleSequentialInstructionPlan([
  wrapSOL,
  swap,
  unwrapSOL,
]);
```

### Nested (complex flows)

```typescript
import {
  sequentialInstructionPlan,
  parallelInstructionPlan,
  nonDivisibleSequentialInstructionPlan,
  executePlan,
} from "@pipeit/core";

const plan = sequentialInstructionPlan([
  parallelInstructionPlan([depositA, depositB]), // both deposits batched/parallel
  activateVault, // then activate
  parallelInstructionPlan([withdrawA, withdrawB]), // then both withdrawals
]);

const result = await executePlan(plan, { rpc, rpcSubscriptions, signer });
```

---

## Reading the result

`executePlan` returns a `TransactionPlanResult`:

```typescript
import { TransactionPlanResult } from "@pipeit/core";

const result = await executePlan(plan, config);

// Flatten all transaction results
import { flattenTransactionPlan } from "@pipeit/core";
const flat = flattenTransactionPlan(result);
```

The result structure mirrors the plan structure — sequential results contain
nested results for each step/batch.

---

## Advanced: Kit planner directly

For maximum control, use Kit's planner and executor directly (all re-exported):

```typescript
import {
  createTransactionPlanner,
  createTransactionPlanExecutor,
  getLinearMessagePackerInstructionPlan,
} from "@pipeit/core";

const planner = createTransactionPlanner({ feePayer: signer });
const executor = createTransactionPlanExecutor({ rpc, rpcSubscriptions });

const transactionPlan = await planner(instructionPlan);
const result = await executor(transactionPlan);
```

---

## Key difference from createFlow

`executePlan` uses Kit's **static planner** — all instructions must be known before
execution starts. It cannot dynamically create instructions based on previous results.

`createFlow` is **dynamic** — each step runs after the previous one confirms,
and can use the previous result to build the next instruction.

Use `executePlan` when you have the full instruction list upfront and want Kit's
optimal batching. Use `createFlow` when instructions depend on runtime data.
