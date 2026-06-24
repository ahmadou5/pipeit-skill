# Server API

`@pipeit/core/server` exports a Next.js API route handler that proxies
TPU transaction submission from browser clients.

**Why:** Direct TPU submission requires native QUIC connections, which browsers
cannot make. The server-side handler bridges this gap.

**This export is Node.js only.** Never import `@pipeit/core/server` in browser/client code.

---

## Setup: Next.js API route

### App Router (recommended)

```typescript
// app/api/tpu/route.ts
export { tpuHandler as POST } from "@pipeit/core/server";
```

That's it. One line. The handler reads the transaction from the request body,
submits it via TPU, and returns confirmation status.

### With custom RPC config

```typescript
// app/api/tpu/route.ts
import { tpuHandler } from "@pipeit/core/server";

export async function POST(request: Request) {
  return tpuHandler(request, {
    rpcUrl: process.env.RPC_URL,
    wsUrl: process.env.WS_URL,
    fanout: 4, // send to 4 upcoming leaders (default: 2)
  });
}
```

### Pages Router

```typescript
// pages/api/tpu.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { tpuHandler } from "@pipeit/core/server";

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  // Convert Next.js req/res to Web Request/Response
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }
  // tpuHandler expects a standard Web API Request
  const webRequest = new Request(`http://localhost/api/tpu`, {
    method: "POST",
    headers: req.headers as HeadersInit,
    body: JSON.stringify(req.body),
  });
  return tpuHandler(webRequest);
}
```

---

## Environment variables for server handler

```bash
# .env.local
RPC_URL=https://your-rpc-provider.com
WS_URL=wss://your-rpc-provider.com   # optional, derived from RPC_URL if not set
```

The handler reads these automatically when no `defaultConfig` is passed:

```typescript
export { tpuHandler as POST } from "@pipeit/core/server";
// Uses process.env.RPC_URL and process.env.WS_URL
```

---

## Client-side usage

Configure `TransactionBuilder` to use your API route for TPU:

```typescript
// Client component / browser code
await builder.execute({
  rpcSubscriptions,
  execution: {
    tpu: {
      enabled: true,
      apiRoute: "/api/tpu", // default, can omit
    },
  },
});
```

Or with the `'ultra'` preset (uses `/api/tpu` by default):

```typescript
await builder.execute({
  rpcSubscriptions,
  execution: "ultra",
});
```

---

## Request / Response types

### Request body (sent by pipeit client automatically)

```typescript
interface TpuHandlerRequest {
  transaction: string; // base64-encoded signed transaction
  config?: {
    rpcUrl?: string;
    wsUrl?: string;
    fanout?: number;
  };
}
```

### Response

```typescript
interface TpuHandlerResponse {
  confirmed: boolean; // definitive success indicator
  signature: string; // base58 transaction signature
  rounds: number; // send rounds attempted
  totalLeadersSent: number; // total leader sends across rounds
  latencyMs: number; // ms from submission to confirmation
  error?: string; // error message if failed
}
```

---

## Security considerations

The TPU handler submits **already-signed** transactions. The server cannot
modify or forge transactions — it only forwards them. However, you should:

1. **Rate limit** the endpoint to prevent abuse:

```typescript
// app/api/tpu/route.ts
import { tpuHandler } from "@pipeit/core/server";
import { rateLimit } from "your-rate-limit-lib";

export async function POST(request: Request) {
  const ip = request.headers.get("x-forwarded-for") ?? "unknown";
  if (await rateLimit(ip, { limit: 10, window: "1m" })) {
    return Response.json({ error: "Rate limited" }, { status: 429 });
  }
  return tpuHandler(request, { rpcUrl: process.env.RPC_URL });
}
```

2. **Do not** expose sensitive RPC credentials in the response.
3. The endpoint should be **authenticated** in production if you're on a paid RPC plan.

---

## TPU error handling

```typescript
import {
  isTpuSubmissionError,
  isTpuRetryableError,
  TpuSubmissionError,
} from "@pipeit/core";

try {
  await builder.execute({ rpcSubscriptions, execution: "ultra" });
} catch (error) {
  if (isTpuSubmissionError(error)) {
    console.error("TPU error code:", error.code);
    console.error("Retryable:", error.retryable);
    console.error("Validator:", error.validatorIdentity);

    if (error.retryable) {
      // Safe to retry — transient network issue
      // Builder's autoRetry handles this automatically
    }
  }
}
```

### TPU error codes

```typescript
type TpuErrorCode =
  | "CONNECTION_FAILED" // QUIC connection could not be established
  | "STREAM_CLOSED" // Connection dropped mid-send
  | "RATE_LIMITED" // Validator rejected due to rate limit
  | "NO_LEADERS" // Could not determine upcoming leaders
  | "TIMEOUT" // Send timed out
  | "VALIDATOR_UNREACHABLE" // Validator TPU port unreachable
  | "ZERO_RTT_REJECTED"; // 0-RTT QUIC rejected, needs full handshake

// Retryable codes (safe to retry immediately)
const TPU_RETRYABLE_ERRORS: TpuErrorCode[] = [
  "STREAM_CLOSED",
  "TIMEOUT",
  "ZERO_RTT_REJECTED",
];
```
