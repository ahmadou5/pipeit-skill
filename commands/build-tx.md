# /build-tx

Scaffold a complete pipeit transaction from scratch.

## Usage

```
/build-tx
```

## What this command does

Prompts for:

1. What the transaction does (e.g. "swap SOL for USDC on Orca")
2. Execution strategy (standard / economical / fast / ultra)
3. Target environment (mainnet / devnet / local)
4. Whether this is server-side (Node.js) or client-side (browser/Next.js)

Then generates:

- Full TypeScript code using `TransactionBuilder` or `createFlow` as appropriate
- Proper RPC + signer setup for the target environment
- Priority fee and compute unit config
- Error handling with appropriate type guards
- Console logging with `logLevel: 'verbose'` (can be removed for production)

## Output structure

```typescript
// 1. Imports
import { TransactionBuilder } from '@pipeit/core';
import { createSolanaRpc, createSolanaRpcSubscriptions } from '@solana/kit';
// ...protocol-specific imports

// 2. RPC setup
const rpc = createSolanaRpc('...');
const rpcSubscriptions = createSolanaRpcSubscriptions('...');

// 3. Signer setup
const signer = await generateKeyPairSigner(); // or wallet adapter

// 4. Build instruction(s)
// NOTE: Replace with actual instruction from your protocol SDK
const ix = yourProtocolInstruction({...});

// 5. Build + execute
const signature = await new TransactionBuilder({
  rpc,
  autoRetry: true,
  priorityFee: 'medium',
  computeUnits: { strategy: 'simulate' },
  logLevel: 'verbose',
})
  .setFeePayerSigner(signer)
  .addInstruction(ix)
  .execute({
    rpcSubscriptions,
    execution: 'standard', // change to 'fast' for production
    commitment: 'confirmed',
  });

console.log(`https://solscan.io/tx/${signature}`);
```

## Notes

- Always outputs TypeScript (no JavaScript)
- Uses `pnpm` for install commands
- Includes install commands for all required peer deps
- Production code uses `logLevel: 'silent'` (verbose only in scaffolds)
