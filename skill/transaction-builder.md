# TransactionBuilder

The primary API. Use this for single transactions.

---

## Minimal example

```typescript
import { TransactionBuilder } from "@pipeit/core";
import { createSolanaRpc, createSolanaRpcSubscriptions } from "@solana/kit";
import { generateKeyPairSigner } from "@solana/signers";

const rpc = createSolanaRpc("https://api.mainnet-beta.solana.com");
const rpcSubscriptions = createSolanaRpcSubscriptions(
  "wss://api.mainnet-beta.solana.com",
);
const signer = await generateKeyPairSigner();

const signature = await new TransactionBuilder({ rpc, autoRetry: true })
  .setFeePayerSigner(signer)
  .addInstruction(myInstruction) // instruction from any Solana SDK
  .execute({ rpcSubscriptions });
```

---

## Constructor config

```typescript
interface TransactionBuilderConfig {
  version?: 0 | "legacy"; // default: 0 (versioned tx)
  rpc?: Rpc<GetLatestBlockhashApi & GetAccountInfoApi>;
  autoRetry?:
    | boolean
    | {
        maxAttempts: number;
        backoff: "linear" | "exponential";
      };
  logLevel?: "silent" | "minimal" | "verbose"; // default: silent
  priorityFee?: PriorityFeeLevel | PriorityFeeConfig;
  computeUnits?: "auto" | number | ComputeUnitConfig;
  lookupTableAddresses?: Address[];
  addressesByLookupTable?: AddressesByLookupTableAddress;
}
```

**Always pass `rpc` in the constructor** — it enables auto-blockhash fetching.
Without it you must manually call `setBlockhashLifetime()`.

---

## Setting the fee payer

Use `setFeePayerSigner()` when executing (signs the transaction):

```typescript
builder.setFeePayerSigner(signer); // TransactionSigner — recommended
```

Use `setFeePayer()` only when building/exporting without executing:

```typescript
builder.setFeePayer(address("AbC...")); // Address only — no signing
```

---

## Adding instructions

```typescript
// Single instruction
builder.addInstruction(ix);

// Multiple instructions
builder.addInstructions([ix1, ix2, ix3]);
```

Instructions come from protocol SDKs. Pipeit does not generate them:

```typescript
// Example: System transfer
import { getTransferSolInstruction } from "@solana-program/system";
import { lamports } from "@solana/rpc-types";

const ix = getTransferSolInstruction({
  source: signer,
  destination: address("Dest111..."),
  amount: lamports(1_000_000n), // 0.001 SOL
});

builder.addInstruction(ix);
```

---

## Priority fees

### Preset levels (micro-lamports per CU)

```typescript
new TransactionBuilder({ priorityFee: "none" }); // 0
new TransactionBuilder({ priorityFee: "low" }); // 1,000
new TransactionBuilder({ priorityFee: "medium" }); // 10,000  ← default if set
new TransactionBuilder({ priorityFee: "high" }); // 50,000
new TransactionBuilder({ priorityFee: "veryHigh" }); // 100,000
```

### Fixed custom fee

```typescript
new TransactionBuilder({
  priorityFee: {
    strategy: "fixed",
    microLamports: 25_000,
  },
});
```

### Percentile-based (uses `getRecentPrioritizationFees` RPC)

```typescript
new TransactionBuilder({
  priorityFee: {
    strategy: "percentile",
    percentile: 75, // 75th percentile of recent fees
    lockedWritableAccounts: [poolAddress], // optional: scoped to specific accounts
  },
});
```

---

## Compute units

### Auto (no explicit instruction, uses Solana default 200k)

```typescript
new TransactionBuilder({ computeUnits: "auto" });
```

### Fixed limit

```typescript
new TransactionBuilder({ computeUnits: 300_000 });
```

### Simulate strategy (most accurate — estimates before sending)

```typescript
new TransactionBuilder({
  computeUnits: { strategy: "simulate" }, // adds 10% buffer by default
});

// Custom buffer
new TransactionBuilder({
  computeUnits: { strategy: "simulate", buffer: 1.2 }, // 20% buffer
});
```

The `simulate` strategy:

1. Adds a provisory CU limit instruction during `build()`
2. Simulates the transaction to get real CU consumption
3. Updates the instruction with estimated value + buffer before signing

---

## Address lookup tables (ALTs)

Only works with versioned transactions (`version: 0`, the default).

```typescript
// Option 1: provide addresses, auto-fetched
new TransactionBuilder({
  version: 0,
  lookupTableAddresses: [
    address("ALT1111111111111111111111111111111111111111"),
  ],
});

// Option 2: pre-fetched data (avoids extra RPC call)
new TransactionBuilder({
  version: 0,
  addressesByLookupTable: {
    [altAddress]: [addr1, addr2, addr3],
  },
});
```

---

## Build (message only — no signing)

Fetches blockhash automatically if `rpc` is set:

```typescript
const message = await builder.build();
```

Requires `setFeePayer()` or `setFeePayerSigner()` + `rpc` in constructor.

---

## Simulate

Test before sending. Does not require a blockhash from on-chain:

```typescript
const result = await builder.simulate();

if (result.err) {
  console.error("Simulation failed:", result.logs);
} else {
  console.log("CU consumed:", result.unitsConsumed);
}
```

Returns `SimulationResult`:

```typescript
interface SimulationResult {
  err: unknown | null;
  logs: string[] | null;
  unitsConsumed: bigint | undefined;
  returnData: any;
}
```

---

## Execute

Signs and sends the transaction. Requires `rpcSubscriptions` for confirmation:

```typescript
const signature = await builder.execute({ rpcSubscriptions });
```

### Execute options

```typescript
const signature = await builder.execute({
  rpcSubscriptions,
  commitment: "confirmed", // 'processed' | 'confirmed' | 'finalized'
  skipPreflight: false,
  skipPreflightOnRetry: true, // skip preflight on retry attempts
  maxRetries: 5,
  preflightCommitment: "confirmed",
  confirmationStrategy: "auto", // 'auto' | 'blockheight' | 'timeout'
  confirmationTimeout: 60_000, // ms, for 'timeout' strategy
  abortSignal: controller.signal,
  execution: "fast", // see execution-strategies.md
});
```

---

## Export (sign without sending)

For custom transports, hardware wallets, QR codes, batch sending:

```typescript
// base64 — for RPC sendTransaction
const { data: base64Tx } = await builder.export("base64");

// base58 — human-readable, for block explorers
const { data: base58Tx } = await builder.export("base58");

// bytes — for hardware wallets
const { data: bytes } = await builder.export("bytes");
```

---

## Durable nonce transactions

For offline signing or guaranteed execution windows:

```typescript
// Auto-fetches nonce from account
const builder = await TransactionBuilder.withDurableNonce({
  rpc,
  nonceAccountAddress: address("NonceAcct111..."),
  nonceAuthorityAddress: address("Authority111..."),
  // ...any other TransactionBuilderConfig options
});

const signature = await builder
  .setFeePayerSigner(signer)
  .addInstruction(ix)
  .execute({ rpcSubscriptions });
```

Or manually:

```typescript
builder.setDurableNonceLifetime(
  nonce,
  nonceAccountAddress,
  nonceAuthorityAddress,
);
```

---

## Check transaction size

Before adding more instructions, verify space remains:

```typescript
const info = await builder.getSizeInfo();
// {
//   size: 512,
//   limit: 1232,
//   remaining: 720,
//   percentUsed: 41.6,
//   canFitMore: true
// }

if (!info.canFitMore) {
  // split into multiple transactions
}
```

---

## Auto-retry config

```typescript
// Default retry (3 attempts, exponential backoff)
new TransactionBuilder({ autoRetry: true });

// Custom retry
new TransactionBuilder({
  autoRetry: {
    maxAttempts: 5,
    backoff: "exponential", // or 'linear'
  },
});
```

---

## Immutability

`TransactionBuilder` is immutable — each method returns a new instance.
You can safely branch from the same builder:

```typescript
const base = new TransactionBuilder({ rpc })
  .setFeePayerSigner(signer)
  .addInstruction(ix1);

const withHighFee = base.addInstruction(ix2); // separate instance
const withLowFee = base.addInstruction(ix3); // separate instance
```

---

## Type safety

The builder uses TypeScript phantom types to enforce required fields at compile time.
`build()` and `execute()` are only available after `setFeePayer/setFeePayerSigner()` is called:

```typescript
// ✅ Compiles
await new TransactionBuilder({ rpc })
  .setFeePayerSigner(signer) // unlocks build() / execute()
  .addInstruction(ix)
  .execute({ rpcSubscriptions });

// ❌ TypeScript error — execute() doesn't exist yet
await new TransactionBuilder({ rpc })
  .addInstruction(ix)
  .execute({ rpcSubscriptions });
```
