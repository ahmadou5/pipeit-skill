# Error Handling

Pipeit provides typed errors, type guards, and a diagnostic utility
that maps raw Solana errors to actionable descriptions.

---

## Quick pattern

```typescript
import {
  isBlockhashExpiredError,
  isSimulationFailedError,
  isTransactionTooLargeError,
  isInsufficientFundsError,
  isTpuSubmissionError,
  diagnoseError,
  formatDiagnosis,
  TransactionTooLargeError,
  InsufficientFundsError,
} from "@pipeit/core";

try {
  const sig = await builder.execute({ rpcSubscriptions });
} catch (error) {
  if (isBlockhashExpiredError(error)) {
    // Re-fetch blockhash and retry
  } else if (isSimulationFailedError(error)) {
    // Check logs — program rejected the instruction
  } else if (isTransactionTooLargeError(error)) {
    // Split into multiple transactions
  } else if (isInsufficientFundsError(error)) {
    const e = error as InsufficientFundsError;
    console.error(`Need ${e.required} lamports, have ${e.available}`);
  } else if (isTpuSubmissionError(error)) {
    // TPU-specific — see execution-strategies.md
  } else {
    // Use diagnoseError for unknown errors
    const diagnosis = diagnoseError(error);
    console.error(formatDiagnosis(diagnosis));
  }
}
```

---

## diagnoseError

The most useful utility for debugging. Maps any Solana or Pipeit error to
a structured diagnosis with summary, details, and a suggested fix.

```typescript
import { diagnoseError, formatDiagnosis } from "@pipeit/core";

const diagnosis = diagnoseError(error);
// {
//   category: 'program_error',
//   summary: 'Program returned error on instruction 2',
//   details: 'Custom program error 0x1 from ComputeBudget111...',
//   suggestion: 'Check instruction accounts and data. Increase compute budget.',
//   programAddress: 'ComputeBudget111111111111111111111111111111',
//   instructionIndex: 2,
//   errorCode: 1,
//   logs: ['Program log: ...'],
//   originalError: <original error>,
// }

// Print human-readable diagnosis
console.error(formatDiagnosis(diagnosis));
```

### Error categories

```typescript
type ErrorCategory =
  | "blockhash_expired" // Blockhash too old — re-fetch and retry
  | "insufficient_funds" // Account balance too low
  | "missing_signature" // Fee payer or required signer missing
  | "simulation_failed" // Preflight simulation failed
  | "program_error" // On-chain program rejected instruction
  | "invalid_account" // Account doesn't exist or wrong owner
  | "invalid_data" // Instruction data malformed
  | "network_error" // RPC or network connectivity issue
  | "user_rejected" // Wallet user declined to sign
  | "unknown"; // Unrecognized error
```

---

## Pipeit error classes

### TransactionTooLargeError

Thrown when transaction size exceeds 1232 bytes.

```typescript
import {
  TransactionTooLargeError,
  isTransactionTooLargeError,
} from "@pipeit/core";

if (isTransactionTooLargeError(error)) {
  const e = error as TransactionTooLargeError;
  console.error(`Size: ${e.size} bytes, limit: ${e.maxSize} bytes`);
  // Solution: split into multiple transactions or add ALTs
}
```

**Fix:** Use `builder.getSizeInfo()` before executing to detect early,
or add address lookup tables (`lookupTableAddresses`).

### InsufficientFundsError

```typescript
import { InsufficientFundsError, isInsufficientFundsError } from "@pipeit/core";

if (isInsufficientFundsError(error)) {
  const e = error as InsufficientFundsError;
  console.error(`Required: ${e.required} lamports`);
  console.error(`Available: ${e.available} lamports`);
  if (e.account) console.error(`Account: ${e.account}`);
}
```

### SignatureRejectedError

User declined signing in wallet.

```typescript
import { isSignatureRejectedError } from "@pipeit/core";

if (isSignatureRejectedError(error)) {
  // User cancelled — don't show an error, just return gracefully
}
```

### AccountNotFoundError

```typescript
import { isAccountNotFoundError, AccountNotFoundError } from "@pipeit/core";

if (isAccountNotFoundError(error)) {
  const e = error as AccountNotFoundError;
  console.error(`Account not found: ${e.account}`);
}
```

### TransactionExecutionError

Transaction confirmed on-chain but program execution failed.
This is a "successful" transaction that returned an error — fees are still charged.

```typescript
import { TransactionExecutionError } from "@pipeit/core";

if (error instanceof TransactionExecutionError) {
  console.error("Signature:", error.signature);
  console.error("Program error:", error.err);
  // Check https://solscan.io/tx/${error.signature} for logs
}
```

---

## Kit error guards (re-exported)

```typescript
import {
  isBlockhashExpiredError,
  isSimulationFailedError,
  isSolanaError,
} from "@pipeit/core";

// Blockhash expired — SOLANA_ERROR__BLOCK_HEIGHT_EXCEEDED
isBlockhashExpiredError(error); // → boolean

// Preflight simulation failed
isSimulationFailedError(error); // → boolean

// General Kit error check
import { SOLANA_ERROR__TRANSACTION__FEE_PAYER_MISSING } from "@pipeit/core";
isSolanaError(error, SOLANA_ERROR__TRANSACTION__FEE_PAYER_MISSING);
```

### Known error constants

```typescript
import {
  ERROR_FEE_PAYER_MISSING,
  ERROR_BLOCKHASH_EXPIRED,
  ERROR_SIMULATION_FAILED,
} from "@pipeit/core";

// ERROR_FEE_PAYER_MISSING  = 5663011
// ERROR_BLOCKHASH_EXPIRED  = 1
// ERROR_SIMULATION_FAILED  = -32002
```

---

## Network error detection

```typescript
import { isNetworkError, isTpuNetworkError } from "@pipeit/core";

// Generic network error (RPC connectivity, timeout, etc.)
isNetworkError(error);

// TPU-specific network error (connection failed, stream closed, etc.)
isTpuNetworkError(error);
```

---

## Error utilities

```typescript
import { getErrorMessage, formatError } from "@pipeit/core";

// Human-readable message for Pipeit errors
const msg = getErrorMessage(error as PipeitErrorType);

// Format any error for logging
const formatted = formatError(error); // handles unknown types safely
```

---

## Retry patterns

### Blockhash expired — retry with fresh blockhash

`autoRetry: true` handles this automatically in `TransactionBuilder`.
For manual control:

```typescript
async function sendWithRetry(maxAttempts = 3) {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await new TransactionBuilder({ rpc })
        .setFeePayerSigner(signer)
        .addInstruction(ix)
        .execute({ rpcSubscriptions });
    } catch (error) {
      if (isBlockhashExpiredError(error) && attempt < maxAttempts - 1) {
        console.log("Blockhash expired, retrying...");
        continue;
      }
      throw error;
    }
  }
}
```

### Simulation failure — log and inspect

```typescript
try {
  await builder.execute({ rpcSubscriptions });
} catch (error) {
  if (isSimulationFailedError(error)) {
    // Run simulation explicitly to get logs
    const result = await builder.simulate();
    console.error("Simulation logs:");
    result.logs?.forEach((log) => console.error(" ", log));
  }
}
```

---

## Validation utilities

Check before sending:

```typescript
import {
  validateTransaction,
  validateTransactionSize,
  getTransactionSizeInfo,
  TRANSACTION_SIZE_LIMIT,
} from "@pipeit/core";

const message = await builder.build();

// Throws if required fields missing
validateTransaction(message);

// Throws TransactionTooLargeError if too large
validateTransactionSize(message);

// Get size info without throwing
const info = getTransactionSizeInfo(message);
console.log(`${info.percentUsed.toFixed(1)}% of limit used`);
```
