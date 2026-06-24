# Pipeit Setup

## Installation

```bash
pnpm install @pipeit/core @solana/kit
```

`@pipeit/core` has zero runtime dependencies. All `@solana/*` packages are peer dependencies
and must be installed explicitly.

### Full peer deps (copy-paste for new projects)

```bash
pnpm install @pipeit/core \
  @solana/kit \
  @solana/addresses \
  @solana/codecs-strings \
  @solana/errors \
  @solana/functional \
  @solana/instruction-plans \
  @solana/instructions \
  @solana/programs \
  @solana/rpc \
  @solana/rpc-subscriptions \
  @solana/rpc-types \
  @solana/signers \
  @solana/transaction-messages \
  @solana/transactions \
  @solana-program/compute-budget
```

### Minimal install (most projects only need)

```bash
pnpm install @pipeit/core @solana/kit @solana-program/compute-budget
```

`@solana/kit` re-exports everything from the individual `@solana/*` packages.

---

## ESM-only

`@pipeit/core` is ESM-only (`"type": "module"`). Your project must support ESM.

**Next.js:** works out of the box with App Router.

**Node.js scripts:** use `.mjs` extension or `"type": "module"` in `package.json`.

**tsconfig.json** — recommended settings:

```json
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "target": "ES2022"
  }
}
```

---

## RPC Setup

### Mainnet (production)

```typescript
import { createSolanaRpc, createSolanaRpcSubscriptions } from "@solana/kit";

const rpc = createSolanaRpc("https://api.mainnet-beta.solana.com");
const rpcSubscriptions = createSolanaRpcSubscriptions(
  "wss://api.mainnet-beta.solana.com",
);
```

**Recommended RPC providers:** Helius, QuickNode, Triton — public endpoints will rate-limit under load.

### Devnet

```typescript
const rpc = createSolanaRpc("https://api.devnet.solana.com");
const rpcSubscriptions = createSolanaRpcSubscriptions(
  "wss://api.devnet.solana.com",
);
```

### Local validator

```typescript
const rpc = createSolanaRpc("http://127.0.0.1:8899");
const rpcSubscriptions = createSolanaRpcSubscriptions("ws://127.0.0.1:8900");
```

---

## Signer Setup

Pipeit uses `TransactionSigner` from `@solana/signers`.

### From a keypair file (Node.js / scripts)

```typescript
import { createKeyPairSignerFromBytes } from "@solana/signers";
import { readFileSync } from "fs";

const secretKey = Uint8Array.from(
  JSON.parse(readFileSync("/path/to/keypair.json", "utf-8")),
);
const signer = await createKeyPairSignerFromBytes(secretKey);
console.log("Address:", signer.address);
```

### Generate a new keypair (dev/testing)

```typescript
import { generateKeyPairSigner } from "@solana/signers";

const signer = await generateKeyPairSigner();
```

### Browser wallet (via wallet adapter)

Wallet adapters that implement `TransactionSigner` work directly.
If using `@solana/wallet-adapter-*`, wrap the adapter:

```typescript
import { createNoopSigner } from "@solana/signers";
import { address } from "@solana/addresses";

// When you need to pass address only (read-only / not executing)
const signer = createNoopSigner(address(walletPublicKey.toBase58()));
```

For actual signing, use a wallet adapter that returns a `TransactionSigner`-compatible object.

---

## Environment Variables Pattern

For apps, keep RPC URLs in env vars:

```typescript
// lib/rpc.ts
import { createSolanaRpc, createSolanaRpcSubscriptions } from "@solana/kit";

const RPC_URL =
  process.env.NEXT_PUBLIC_RPC_URL ?? "https://api.mainnet-beta.solana.com";
const WS_URL = RPC_URL.replace(/^https?/, (p) =>
  p === "https" ? "wss" : "ws",
);

export const rpc = createSolanaRpc(RPC_URL);
export const rpcSubscriptions = createSolanaRpcSubscriptions(WS_URL);
```

---

## Exports

`@pipeit/core` has two export paths:

| Import path           | Contents                                                                |
| --------------------- | ----------------------------------------------------------------------- |
| `@pipeit/core`        | `TransactionBuilder`, `createFlow`, `executePlan`, all types, utilities |
| `@pipeit/core/server` | `tpuHandler` for Next.js API routes                                     |

The `/server` export must only be used in server-side code (Node.js / Next.js API routes).
It will fail if imported in the browser.
