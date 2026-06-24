# Resources

## Package

- **npm:** [`@pipeit/core`](https://www.npmjs.com/package/@pipeit/core)
- **GitHub:** [stevesarmiento/pipeit](https://github.com/stevesarmiento/pipeit)
- **Current version:** `0.2.7` (February 2026)
- **License:** MIT

## Dependencies

| Package                                                                                             | Role                                    |
| --------------------------------------------------------------------------------------------------- | --------------------------------------- |
| [`@solana/kit`](https://github.com/anza-xyz/kit)                                                    | Core Solana JS SDK (web3.js 2.x)        |
| [`@solana/instruction-plans`](https://github.com/anza-xyz/kit/tree/main/packages/instruction-plans) | Kit's transaction planner (re-exported) |
| [`@solana-program/compute-budget`](https://www.npmjs.com/package/@solana-program/compute-budget)    | CU limit + priority fee instructions    |

## Related packages

| Package                      | Purpose                                                            |
| ---------------------------- | ------------------------------------------------------------------ |
| `@pipeit/fastlane`           | Native TPU client for direct validator submission (`ultra` preset) |
| `@solana-program/system`     | System program instructions (SOL transfer, account creation)       |
| `@solana-program/token`      | SPL token instructions                                             |
| `@solana-program/token-2022` | Token Extensions instructions                                      |

## Solana Kit docs

- [Kit overview](https://www.solanakit.com/docs)
- [Transaction building](https://github.com/anza-xyz/kit/tree/main/packages/transaction-messages)
- [Instruction plans](https://github.com/anza-xyz/kit/tree/main/packages/instruction-plans)
- [Signers](https://github.com/anza-xyz/kit/tree/main/packages/signers)

## Changelog

### 0.2.7 (Feb 2026)

- Server export `@pipeit/core/server` with `tpuHandler` for Next.js routes
- TPU error types: `TpuSubmissionError`, `isTpuSubmissionError`, `isTpuRetryableError`
- `ExecutionResult.tpuDetails` with per-leader breakdown
- `'ultra'` execution preset (TPU + Jito race)

### 0.2.6 (Dec 2025)

- `execution` config on `TransactionBuilder.execute()` and `createFlow()`
- Jito bundle support: `sendBundle`, `getBundleStatuses`, `createTipInstruction`
- Parallel RPC submission: `submitParallel`
- `ExecutionPreset`: `'standard'`, `'economical'`, `'fast'`

### 0.2.5 (Dec 2025)

- `diagnoseError()` and `formatDiagnosis()` error diagnostics
- `isTpuNetworkError()` type guard

### 0.2.4 (Dec 2025)

- `executePlan()` ALT support: `lookupTableAddresses` + `addressesByLookupTable`
- `fetchAddressLookupTables()` utility

### 0.2.3 (Dec 2025)

- `createFlow()` Flow API: `.step()`, `.atomic()`, `.transaction()`, lifecycle hooks
- `ExecutionStrategy`: `'auto'`, `'batch'`, `'sequential'`

### 0.2.2 (Dec 2025)

- `TransactionBuilder.withDurableNonce()` static factory
- Durable nonce utilities: `fetchNonceValue`, `fetchNonceAccount`

### 0.2.1 (Dec 2025)

- `computeUnits: { strategy: 'simulate' }` — provisory CU estimation
- `builder.getSizeInfo()` — transaction size info before building

### 0.2.0 (Dec 2025)

- Initial release
- `TransactionBuilder` with auto-blockhash, auto-retry, priority fees
- `executePlan()` Kit instruction-plans wrapper
- `export()` in base64, base58, bytes formats
