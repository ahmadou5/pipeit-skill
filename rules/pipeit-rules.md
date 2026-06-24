# Pipeit Rules

Rules enforced by the pipeit-engineer agent and this skill.

---

## API surface rules

- Use only methods that exist in `@pipeit/core` v0.2.7
- Do NOT invent method names or parameters not in the type definitions
- All types are importable from `@pipeit/core` — never re-define them locally
- `@pipeit/core/server` is server-only — never use in browser/client code

## TypeScript rules

- No `any` on pipeit or `@solana/kit` API calls
- Use `Address<string>` from `@solana/addresses`, not raw strings for addresses
- Use `lamports(BigInt)` from `@solana/rpc-types` for SOL amounts, not raw numbers
- Signer type is `TransactionSigner` from `@solana/signers`

## Transaction builder rules

- ALWAYS call `setFeePayerSigner(signer)` before `execute()` — never `setFeePayer(address)` when executing
- ALWAYS pass `rpc` to constructor — enables auto-blockhash; without it `build()` will throw
- ALWAYS set `computeUnits` for production transactions — never rely on Solana's 200k default for swap/DeFi instructions
- For production: use `computeUnits: { strategy: 'simulate' }` or a fixed value based on profiling
- For priority fees in production: use `'medium'` minimum, `'high'` for time-sensitive transactions
- Use `autoRetry: true` in production — blockhash expiry is common under load

## Flow rules

- Step names must be unique within a flow
- `.atomic()` groups must fit in a single transaction — check size with `getSizeInfo()` first
- Use `.transaction()` steps only when you genuinely need on-chain state from the previous tx
- Access previous results via `ctx.get('step-name')` — returns `FlowStepResult | undefined`

## Execution strategy rules

- Default is `'standard'` — explicitly set for clarity
- Use `'fast'` or `'economical'` for mainnet production
- Never use `'ultra'` without `@pipeit/fastlane` installed
- Jito tips: minimum 1,000 lamports (`JITO_MIN_TIP_LAMPORTS`), default 10,000 (`JITO_DEFAULT_TIP_LAMPORTS`)

## Error handling rules

- Always catch and type-guard errors from `execute()` and `createFlow().execute()`
- Always handle `isBlockhashExpiredError` — use retry or `autoRetry: true`
- For user-facing apps: handle `isSignatureRejectedError` silently (user cancelled)
- Use `diagnoseError()` for unknown errors before surfacing to users

## Install rules

- Use `pnpm` unless user specifies otherwise
- Always install all required peer deps — `@solana/kit` at minimum
- `@pipeit/core` is ESM-only — ensure project supports ESM

## Version

These rules apply to `@pipeit/core` **v0.2.7**.
If the user's version differs, check the changelog in `resources.md`.
