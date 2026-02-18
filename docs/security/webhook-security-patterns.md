# Webhook Security Patterns

> Adopted from optimalAIs/openclaw-with-dailyflows (fork-harvest, score 8.00)

## Patterns Identified

### 1. Body Size Limiting

```typescript
const MAX_BODY_SIZE = 1024 * 1024; // 1MB
// Reject early if payload exceeds limit (prevents memory exhaustion)
```

### 2. Timestamp Skew Validation

```typescript
const MAX_SKEW_MS = 5 * 60 * 1000; // 5 minutes
// Reject stale timestamps to prevent replay attacks
if (Math.abs(Date.now() - parsedTimestamp) > MAX_SKEW_MS) {
  res.statusCode = 401;
  res.end("stale timestamp");
}
```

### 3. Constant-Time Signature Comparison

```typescript
// Use crypto.timingSafeEqual() to prevent timing attacks
import { timingSafeEqual } from "node:crypto";
```

### 4. Request Body Timeout

```typescript
// Timeout protection for slow-loris attacks
private readBody(req, maxBytes, timeoutMs = 30_000) {
  // Kill connection if body not received within timeout
}
```

### 5. Connection Close Handling

```typescript
req.on("close", () => finish(() => reject(new Error("Connection closed"))));
// Handle abrupt disconnects gracefully
```

## Applicability

These patterns should be applied to any webhook endpoint in OpenClaw:

- Voice call webhooks (partially applied upstream)
- Future channel webhooks
- Cron webhook delivery endpoints
