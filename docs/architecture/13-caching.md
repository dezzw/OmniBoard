# 13 — Caching

## Purpose

Define cache tiers, ownership, invalidation, and how provider cache hints interact with Core and renderer snapshot caches (WidgetKit / ActivityKit).

## Cache tiers

```
┌──────────────────────────────────────────────┐
│ Tier C — Renderer snapshot cache             │
│ WidgetKit / ActivityKit timelines, menu bar  │
│ Owned by renderer adapters                   │
├──────────────────────────────────────────────┤
│ Tier B — Core item / RenderDocument cache    │
│ Memory + SQLite; source of truth on device   │
│ Owned by Core CacheLayer + ItemStore         │
├──────────────────────────────────────────────┤
│ Tier A — Provider raw fetch cache            │
│ Upstream HTTP/etc. responses                 │
│ Owned by provider; guided by OPP hints       │
└──────────────────────────────────────────────┘
```

SQLite ItemStore is **authoritative** for offline reads even when memory caches are cold ([15](15-offline-behavior.md)).

## Tier A — Provider raw cache

Providers may cache upstream responses. OPP optional hint on `items/changed`:

```json
{
  "cache": {
    "ttlMs": 60000,
    "tags": ["flights", "AA100"],
    "revalidateAfterMs": 30000
  }
}
```

Core may echo tags for coordinated invalidation but **does not** store raw upstream bytes for the provider.

## Tier B — Core item cache

- Write-through to SQLite on item mutation.
- In-memory LRU for hot Items / RenderDocuments.
- Invalidation: on upsert/delete; on manifest/schema change; on permission-driven data purge.

### Invalidation rules

| Event | Action |
| ----- | ------ |
| `items/changed` upsert | Replace cache entry if `revision` newer |
| delete | Drop entry |
| instance stop/uninstall | Drop instance namespace |
| soft `InvalidRender` | Keep last-good render if available; else placeholder |

## Tier C — Renderer snapshots

Apple timeline APIs impose budgets and latency constraints. Renderer adapters **may**:

1. Materialize SwiftUI-ready snapshots from Render IR at known intervals.
2. Ask Core for a `snapshot/render` Client Protocol method that returns prevalidated IR for a `BoardSurface` slot.
3. Reuse last snapshot when Core is unreachable.

Providers remain declarative; they do not target WidgetKit APIs directly ([05](05-rendering-schema.md), [21](21-risks-and-tradeoffs.md)).

## Freshness metadata

Items carry `asOf` and `staleAfter` ([04](04-data-model.md)). Caches **shall** preserve these fields so UI can show stale affordances without guessing.

## Normative rules

1. Tier B **shall** not serve an item with `revision` older than SQLite after a successful write.
2. Tier C **shall** treat Core SQLite as upstream of truth when reachable.
3. Cache hints **shall** be advisory; Core may ignore under storage pressure.
4. Secrets and auth headers **shall never** be written to Tier B/C caches.

## Non-goals

- Distributed CDN for provider raw caches in v1
- Cross-user shared item caches on Hub without isolation
- Providers pushing opaque binary blobs as a substitute for Items

## Tradeoffs

Three tiers add complexity, but matching Apple’s snapshot model without leaking platform constraints into OPP is necessary for widgets and Live Activities.

## Related

- [14-synchronization.md](14-synchronization.md)
- [15-offline-behavior.md](15-offline-behavior.md)
- [05-rendering-schema.md](05-rendering-schema.md)
