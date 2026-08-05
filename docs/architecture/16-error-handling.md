# 16 — Error Handling

## Purpose

Define the typed error catalog, isolation boundaries, retry hints, user-visible messaging, and telemetry-safe codes.

## Principles

1. Errors are **typed** with stable codes.
2. Provider failures **isolate** to that instance; Core and other providers continue.
3. UI prefers **last-good data + error chip** over blank screens.
4. Messages are layered: machine code + optional `userVisibleMessage` + retry metadata.

## Error catalog

| Code | Name | Typical source | Retry hint |
| ---- | ---- | -------------- | ---------- |
| -32000 | `ProviderCrash` | Supervisor | Restart policy |
| -32001 | `Timeout` | OPP / upstream | Backoff |
| -32002 | `AuthExpired` | Provider / IdP | Re-auth; no tight restart |
| -32003 | `PermissionDenied` | Core | User grant; no restart |
| -32004 | `InvalidRender` | Core IR validation | Soft degrade or hard reject of document |
| -32005 | `RateLimited` | Upstream | `retryAfterMs` |
| -32006 | `StaleData` | Provider | Show stale; refresh later |
| -32007 | `Unavailable` | Transport / Hub | Backoff |
| -32008 | `SyncConflict` | SyncEngine | User resolution |
| -32009 | `InvalidParams` | Schema validation | Fix input |
| -32010 | `NotFound` | Items / actions | Remove bindings |
| -32601 | `MethodNotFound` | JSON-RPC | Capability mismatch |
| -32603 | `InternalError` | Provider / Core | Log + degrade |

JSON-RPC standard codes apply for parse/invalid request.

### Error object shape

```json
{
  "code": -32005,
  "message": "RateLimited",
  "data": {
    "reasonCode": "RateLimited",
    "retryAfterMs": 60000,
    "userVisibleMessage": "GitHub is rate-limiting this provider. Trying again in about a minute.",
    "instanceId": "inst_gh_1",
    "telemetrySafe": true
  }
}
```

`telemetrySafe: true` means `data` contains no secrets or PII beyond coarse ids.

## Isolation

```
Provider A crash ──► instance Failed/Degraded only
Core bug ──────────► process-level (avoid by Rust safety + tests)
Renderer bug ──────► that surface only; Core data intact
```

Supervisor restart policies: [03](03-provider-lifecycle.md).

## InvalidRender policy

| Severity | Behavior |
| -------- | -------- |
| Soft (unknown node) | Fallback / omit; emit `render.invalid` event |
| Hard (root invalid) | Reject write; keep previous item revision; return `InvalidRender` to provider if pull path |

## Mapping to UI

| Error | UI |
| ----- | -- |
| Crash / Unavailable | Last-good + “provider offline” |
| AuthExpired | Last-good + reconnect button |
| PermissionDenied | Last-good + permissions deep link |
| RateLimited | Last-good + countdown if `retryAfterMs` |
| SyncConflict | Banner with resolve action |
| InvalidRender | Placeholder component; developer log |

## Normative rules

1. Every OPP / Client Protocol failure **shall** use a catalog code when applicable.
2. Core **shall** translate provider crashes into `ProviderCrash` for clients, not raw signals.
3. Retry logic **shall** honor `retryAfterMs` when present.
4. User-visible strings **may** be localized keys; codes remain English enum tokens.

## Non-goals

- Automatic silent “fix” of domain errors without provider logic
- Exposing stack traces to end users
- Cross-instance cascading failure as a feature

## Tradeoffs

A fixed catalog constrains expressiveness but keeps multi-language SDKs and UI consistent; providers can add detail in `data` without inventing new top-level codes casually ([17](17-versioning.md)).

## Related

- [03-provider-lifecycle.md](03-provider-lifecycle.md)
- [08-plugin-protocol.md](08-plugin-protocol.md)
- [15-offline-behavior.md](15-offline-behavior.md)
