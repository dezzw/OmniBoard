# 15 — Offline Behavior

## Purpose

Specify offline-first UX: local SQLite as readable source of truth, action queues with idempotency, freshness metadata, and stale affordances.

## Guarantees

1. **Read path always works from local SQLite** when Core is running, even with no network, no Hub, and stopped providers.
2. **Last-good Items and RenderDocuments** remain visible after provider failure.
3. **Stale state is explicit** via `asOf` / `staleAfter` / provider status — UI does not invent freshness.
4. **Actions** may queue when offline according to policy; results apply when the provider returns.

## Read path

```
Renderer → Client Protocol → Core ItemStore (SQLite) → Items + Render IR
```

No provider round-trip is required for board rendering.

## Freshness

| Field | Meaning |
| ----- | ------- |
| `asOf` | Instant the provider asserts the payload reflects |
| `staleAfter` | Instant after which UI should mark stale |
| `provider.status` | `degraded` / `stopped` reinforces stale UX |

Example UI rules (normative intent, visual design free):

- Before `staleAfter`: normal
- After `staleAfter`: stale chip / dimming
- Provider `AuthExpired`: stale + reconnect CTA
- Missing `staleAfter`: use cache TTL hints or show “updated {RelativeTime}” only

## Action queue

```json
{
  "invocationId": "inv_01J…",
  "idempotencyKey": "inv_01J…",
  "actionId": "com.example.flight.checkIn",
  "providerInstanceId": "inst_flight_1",
  "params": {},
  "enqueuedAt": "2026-08-04T20:00:00Z",
  "status": "queued"
}
```

Rules:

1. Queue entries **shall** carry `idempotencyKey`.
2. Destructive, non-idempotent actions **shall** default to rejected-while-offline unless user explicitly confirms queueing.
3. On provider ready, Core drains queue in FIFO per instance with backoff on `RateLimited`.
4. Duplicate keys **shall** not double-apply at the provider ([07](07-action-system.md)).

## Provider offline vs Hub offline

| Situation | Behavior |
| --------- | -------- |
| Provider stopped / network down | Show last-good items; queue eligible actions; status degraded |
| Hub unreachable | Local Core continues; sync pauses; local providers unaffected |
| Both down | Full local read-only + local queue |

## Normative rules

1. Core **shall not** clear last-good items solely because a fetch failed.
2. Renderers **shall** prefer ItemStore over optimistic empty states when data exists.
3. Telemetry (if any) **shall** be buffered and privacy-gated; Core itself requires no phone-home.
4. Widget/Activity snapshots **may** display last Tier C cache when Core is briefly unavailable ([13](13-caching.md)).

## Non-goals

- Guaranteeing provider-side side effects while offline (only queueing)
- Full offline creation of new provider instances that need network install
- Conflict-free offline config edits across devices without later resolution ([14](14-synchronization.md))

## Tradeoffs

Queuing improves UX but risks surprising side effects when connectivity returns; requiring idempotency keys and conservative defaults for destructive actions mitigates that.

## Related

- [13-caching.md](13-caching.md)
- [14-synchronization.md](14-synchronization.md)
- [16-error-handling.md](16-error-handling.md)
