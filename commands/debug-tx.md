# /debug-tx

Diagnose a failed pipeit transaction.

## Usage

```
/debug-tx <error or signature>
```

## What this command does

Given a caught error or a transaction signature, this command:

1. Identifies the error category using pipeit's type guards
2. Runs `diagnoseError()` for unknown errors
3. Suggests the fix with working code

## Diagnosis flow

```
Did the transaction throw before sending?
├── isBlockhashExpiredError → re-fetch blockhash / use autoRetry: true
├── isTransactionTooLargeError → split tx or add ALTs
├── isInsufficientFundsError → check account balance
├── isSignatureRejectedError → user cancelled (not an error)
├── isSimulationFailedError → run builder.simulate() and inspect logs
└── unknown → run diagnoseError(error) and formatDiagnosis(result)

Did the transaction confirm but execution failed?
└── TransactionExecutionError → check solscan logs for program error

Is this a TPU error?
├── isTpuSubmissionError → check error.code and error.retryable
└── isTpuNetworkError → transient — retry with autoRetry: true
```

## Output

For each error type, outputs:

- What happened and why
- The exact code fix
- Whether the transaction fees were charged

## Example output for simulation failure

```
Error category: simulation_failed
Summary: Preflight simulation rejected the transaction.

Suggested fix:
Run simulation explicitly to see program logs:

const result = await builder.simulate();
console.error('Simulation logs:');
result.logs?.forEach(log => console.error(' ', log));

Common causes:
- Slippage exceeded (swap instructions)
- Account validation failed (wrong owner, wrong state)
- Insufficient token balance
- Compute budget too low (increase computeUnits)

Fees charged: NO (simulation failures don't charge fees)
```
