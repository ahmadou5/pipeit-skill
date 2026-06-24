# Flow API

Use `createFlow()` when instructions depend on results from previous transactions.
The flow handles batching automatically — consecutive instruction steps are grouped
into single transactions where possible.

---

## When to use Flow vs TransactionBuilder

| Situation                                                 | Use                                     |
| --------------------------------------------------------- | --------------------------------------- |
| All instructions known upfront, no inter-tx dependencies  | `TransactionBuilder` or `executePlan`   |
| Later instructions need data from earlier tx results      | `createFlow`                            |
| Need to check on-chain state between transactions         | `createFlow` with `transaction()` steps |
| Want fine-grained control over what happens between steps | `createFlow`                            |

---

## Basic example

```typescript
import { createFlow } from '@pipeit/core';
import { createSolanaRpc, createSolanaRpcSubscriptions } from '@solana/kit';

const results = await createFlow({ rpc, rpcSubscriptions, signer })
  .step('create-account', (ctx) => createAccountInstruction(...))
  .step('init-data', (ctx) => {
    // Access previous step result
    const prev = ctx.get('create-account');
    console.log('Previous signature:', prev?.signature);
    return initDataInstruction(...);
  })
  .execute();

console.log('create-account sig:', results.get('create-account')?.signature);
console.log('init-data sig:', results.get('init-data')?.signature);
```

---

## createFlow config

```typescript
interface FlowConfig {
  rpc: Rpc<FlowRpcApi>;
  rpcSubscriptions: RpcSubscriptions<FlowRpcSubscriptionsApi>;
  signer: TransactionSigner;
  strategy?: "auto" | "batch" | "sequential"; // default: 'auto'
  commitment?: "processed" | "confirmed" | "finalized"; // default: 'confirmed'
  execution?: ExecutionConfig; // Jito / parallel / TPU — see execution-strategies.md
}
```

---

## Step types

### `.step()` — instruction step (auto-batched)

Consecutive `.step()` calls are batched into a single transaction automatically.
If batched instructions exceed tx size limit, flow falls back to sequential.

```typescript
flow.step("step-name", (ctx) => instruction);

// Async step creators are supported
flow.step("fetch-and-build", async (ctx) => {
  const data = await fetchSomeData();
  return buildInstruction(data);
});
```

### `.atomic()` — guaranteed single transaction group

Instructions that MUST execute together atomically. Always a single transaction.

```typescript
flow.atomic('swap', [
  (ctx) => wrapSolInstruction(...),
  (ctx) => swapInstruction(...),
  (ctx) => unwrapSolInstruction(...),
]);
```

### `.transaction()` — custom async step (breaks batching)

For operations that need the previous transaction confirmed before proceeding,
or for custom async logic between transactions.

```typescript
flow.transaction("verify-and-act", async (ctx) => {
  const prevResult = ctx.get("create-account");

  // Read on-chain state that was just created
  const accountInfo = await ctx.rpc.getAccountInfo(newAccountAddress).send();
  if (!accountInfo.value) {
    throw new Error("Account not created yet");
  }

  // Can return any signature (e.g. from the previous step)
  return {
    signature: prevResult?.signature ?? "",
    // any additional fields you want to track
  };
});
```

---

## Flow context

Each step receives `FlowContext`:

```typescript
interface FlowContext {
  results: Map<string, FlowStepResult>; // all previous step results
  signer: TransactionSigner;
  rpc: Rpc<FlowRpcApi>;
  rpcSubscriptions: RpcSubscriptions<FlowRpcSubscriptionsApi>;
  get: (stepName: string) => FlowStepResult | undefined; // convenience
}

interface FlowStepResult {
  signature: string;
  instructionIndex?: number; // for batched steps
}
```

---

## Execution strategies

```typescript
// Auto: batch when possible, fallback to sequential (recommended)
createFlow({ rpc, rpcSubscriptions, signer, strategy: "auto" });

// Always batch consecutive instruction steps
createFlow({ rpc, rpcSubscriptions, signer, strategy: "batch" });

// Always one tx per step (maximum isolation, more RPC calls)
createFlow({ rpc, rpcSubscriptions, signer, strategy: "sequential" });
```

**How 'auto' batches:** Consecutive `.step()` calls are grouped and sent as one tx.
A `.transaction()` call or `.atomic()` call always breaks the batch.

```
.step('a')      ┐
.step('b')      ┤ → single transaction [a + b]
.atomic('c', [])┘ → separate transaction [c]
.step('d')        → separate transaction [d]  (follows atomic)
```

---

## Lifecycle hooks

```typescript
createFlow({ rpc, rpcSubscriptions, signer })
  .step("transfer", (ctx) => ix)
  .onStepStart((name) => {
    console.log(`Starting: ${name}`);
  })
  .onStepComplete((name, result) => {
    console.log(`Done: ${name} — ${result.signature}`);
  })
  .onStepError((name, error) => {
    console.error(`Failed: ${name}`, error.message);
    // Flow stops after an error, remaining steps do not execute
  })
  .execute();
```

---

## Real-world pattern: Token account + transfer

```typescript
import { createFlow } from "@pipeit/core";
import { getCreateAssociatedTokenInstructionIfNeeded } from "@solana-program/token"; // illustrative

const results = await createFlow({ rpc, rpcSubscriptions, signer })
  .step("create-ata", async (ctx) => {
    // Only creates ATA if it doesn't exist yet
    const ix = await getCreateAssociatedTokenInstructionIfNeeded({
      payer: ctx.signer,
      owner: recipientAddress,
      mint: tokenMint,
      rpc,
    });
    return ix;
  })
  .step("transfer-tokens", (ctx) => {
    return getTransferCheckedInstruction({
      source: sourceTokenAccount,
      mint: tokenMint,
      destination: recipientTokenAccount,
      authority: ctx.signer,
      amount: 1_000_000n,
      decimals: 6,
    });
  })
  .execute();
```

---

## Real-world pattern: Multi-DEX swap sequence

```typescript
const results = await createFlow({ rpc, rpcSubscriptions, signer })
  .atomic("wrap-and-swap", [
    (ctx) => wrapSOLInstruction({ amount: lamports(1_000_000_000n), signer }),
    (ctx) =>
      swapInstruction({
        inputMint: wSOL,
        outputMint: USDC,
        amount: 1_000_000_000n,
      }),
  ])
  .step("log-result", async (ctx) => {
    const swapSig = ctx.get("wrap-and-swap")?.signature;
    // Fetch post-swap balance or state here
    return noopInstruction(); // placeholder if no on-chain action needed
  })
  .onStepComplete((name, result) => {
    console.log(`${name}: https://solscan.io/tx/${result.signature}`);
  })
  .execute();
```

---

## Error handling in flows

If any step throws, the flow stops immediately. Steps that haven't run are skipped.

```typescript
try {
  const results = await createFlow({ rpc, rpcSubscriptions, signer })
    .step("step1", (ctx) => ix1)
    .step("step2", (ctx) => ix2)
    .execute();
} catch (error) {
  // error is from whichever step failed
  // results from successful steps before the failure are NOT returned here
  // use onStepComplete hook to capture partial results
}
```

To capture partial results, use lifecycle hooks:

```typescript
const completedSteps: Map<string, FlowStepResult> = new Map();

const results = await createFlow({ rpc, rpcSubscriptions, signer })
  .step("step1", (ctx) => ix1)
  .step("step2", (ctx) => ix2)
  .onStepComplete((name, result) => completedSteps.set(name, result))
  .execute();
```
