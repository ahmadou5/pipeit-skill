# Execution Strategies

Pipeit supports four execution modes beyond standard RPC submission.
Pass `execution` to `builder.execute()` or `createFlow()` config.

---

## Presets

```typescript
type ExecutionPreset = "standard" | "economical" | "fast" | "ultra";
```

| Preset         | What it does                  | Cost           | Speed                                         |
| -------------- | ----------------------------- | -------------- | --------------------------------------------- |
| `'standard'`   | Default RPC `sendTransaction` | Lowest         | Normal                                        |
| `'economical'` | Jito bundle only              | Jito tip       | Better landing                                |
| `'fast'`       | Jito + parallel RPC race      | Jito tip + RPC | Best landing probability                      |
| `'ultra'`      | TPU + Jito race               | Jito tip       | Fastest latency (requires `@pipeit/fastlane`) |

### Usage

```typescript
// On TransactionBuilder
const sig = await builder.execute({
  rpcSubscriptions,
  execution: "fast",
});

// On createFlow
const results = await createFlow({
  rpc,
  rpcSubscriptions,
  signer,
  execution: "economical",
})
  .step("swap", (ctx) => ix)
  .execute();
```

---

## Standard (default)

No config needed. Regular `sendTransaction` via the configured RPC.

```typescript
await builder.execute({ rpcSubscriptions });
// or
await builder.execute({ rpcSubscriptions, execution: "standard" });
```

---

## Jito Bundles

MEV protection + higher landing probability. Competes in Jito's auction.
Bundles are atomic — all transactions succeed or none are included.

### Simple Jito

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: "economical", // Jito with default 10,000 lamport tip
});
```

### Custom Jito config

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: {
    jito: {
      enabled: true,
      tipLamports: 50_000n, // 0.00005 SOL
      blockEngineUrl: "ny", // region or full URL
      mevProtection: true, // delay submission to risky leaders
    },
  },
});
```

### Jito regions

```typescript
type JitoBlockEngineRegion =
  | "mainnet" // load-balanced (default)
  | "ny" // New York
  | "amsterdam"
  | "frankfurt"
  | "tokyo"
  | "singapore"
  | "slc"; // Salt Lake City
```

### Tip amount guidance

```
1,000 lamports   — minimum tip, low priority
10,000 lamports  — default, moderate priority
50,000 lamports  — high priority (time-sensitive)
100,000+ lamports — very high (critical trades)
```

### Jito utilities (low-level)

```typescript
import {
  sendBundle,
  sendTransactionViaJito,
  getBundleStatuses,
  createTipInstruction,
  getRandomTipAccount,
  JITO_TIP_ACCOUNTS,
  JITO_DEFAULT_TIP_LAMPORTS,
  JITO_MIN_TIP_LAMPORTS,
} from "@pipeit/core";

// Send custom bundle
const bundleId = await sendBundle([base64Tx1, base64Tx2], {
  blockEngineUrl: "ny",
});

// Check bundle status
const [status] = await getBundleStatuses([bundleId]);
if (status?.confirmationStatus === "confirmed") {
  console.log("Bundle landed!");
}

// Manual tip instruction
const tipIx = createTipInstruction(feePayerAddress, 50_000n);
```

---

## Parallel RPC Submission

Submit to multiple RPC endpoints simultaneously. First to respond wins.
Useful when you have multiple RPC subscriptions (Helius + QuickNode + public).

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: {
    parallel: {
      enabled: true,
      endpoints: ["https://my-helius-rpc.com", "https://my-quicknode-rpc.com"],
      raceWithDefault: true, // also race against the builder's own RPC (default: true)
    },
  },
});
```

### Fast preset = Jito + Parallel

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: "fast", // shorthand for jito + parallel
});
```

### Custom fast config

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: {
    jito: {
      enabled: true,
      tipLamports: 25_000n,
      blockEngineUrl: "ny",
    },
    parallel: {
      enabled: true,
      endpoints: ["https://rpc2.example.com", "https://rpc3.example.com"],
    },
  },
});
```

### submitParallel (low-level)

```typescript
import { submitParallel } from "@pipeit/core";

const result = await submitParallel({
  endpoints: ["https://rpc1.com", "https://rpc2.com"],
  transaction: base64SignedTx,
  skipPreflight: true,
});

console.log(`Landed via ${result.endpoint} in ${result.latencyMs}ms`);
```

---

## Direct TPU Submission

Bypasses RPC nodes entirely. Sends directly to validator QUIC endpoints.
Lowest latency, highest landing probability for time-critical transactions.

**Requires:** `@pipeit/fastlane` package (separate install).
**Browser:** must use the server-side proxy via `@pipeit/core/server` — see [`server.md`](./server.md).

```bash
pnpm install @pipeit/fastlane
```

### TPU config

```typescript
interface TpuConfig {
  enabled: boolean;
  rpcUrl?: string; // for leader schedule (defaults to builder's RPC URL)
  wsUrl?: string; // for slot updates (derived from rpcUrl if not set)
  fanout?: number; // number of leaders to send to (default: 2)
  apiRoute?: string; // browser proxy route (default: '/api/tpu')
}
```

### Ultra preset (TPU + Jito race)

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: "ultra",
});
```

### Custom TPU config

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: {
    tpu: {
      enabled: true,
      fanout: 3, // send to 3 upcoming leaders
      rpcUrl: "https://my-rpc.com",
    },
    jito: {
      enabled: true, // race TPU against Jito simultaneously
      tipLamports: 10_000n,
    },
  },
});
```

---

## ExecutionResult

When using execution strategies, the result includes metadata about how the transaction landed:

```typescript
interface ExecutionResult {
  signature: string;
  landedVia: "jito" | "rpc" | "parallel" | "tpu";
  latencyMs?: number;
  bundleId?: string; // if Jito
  endpoint?: string; // if parallel
  leaderCount?: number; // if TPU
  confirmed?: boolean;
  rounds?: number; // TPU send rounds
  tpuDetails?: TpuSubmissionDetails; // per-leader breakdown for TPU
}
```

`builder.execute()` returns `Promise<string>` (the signature).
`executeWithStrategy()` returns the full `ExecutionResult` for when you need metadata.

---

## Strategy selection guide

```
Is this a time-critical trade or auction?
├── YES → 'ultra' (TPU + Jito) if @pipeit/fastlane available
│          'fast' (Jito + parallel) otherwise
└── NO
    Is MEV protection important?
    ├── YES → 'economical' (Jito only)
    └── NO  → 'standard' (default RPC)
```

---

## Checking strategy config at runtime

```typescript
import { isJitoEnabled, isParallelEnabled, getTipAmount } from "@pipeit/core";

const config: ExecutionConfig = "fast";
console.log(isJitoEnabled(config)); // true
console.log(isParallelEnabled(config)); // true
console.log(getTipAmount(config)); // 10000n (default tip)
```
