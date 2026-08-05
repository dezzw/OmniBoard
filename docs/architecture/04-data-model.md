# 04 — Data Model

## Purpose

Define Core types for manifests, instances, items, snapshots/deltas, actions, events, subscriptions, and board surfaces. Payload schemas are provider-registered; Core validates but does not interpret domain fields.

## Core types

### ProviderManifest

Identity and static contract for a provider package.

```json
{
  "id": "com.example.flights",
  "displayName": "Flights",
  "version": "1.4.0",
  "oppVersion": "1.0",
  "capabilities": ["items.push", "actions.execute", "cache.hints"],
  "permissions": [
    { "id": "network.hosts", "hosts": ["api.airline.example"] },
    { "id": "notifications", "optional": true }
  ],
  "configSchema": { "$ref": "#/schemas/config" },
  "itemTypes": [
    {
      "type": "com.example.flight.status",
      "payloadSchema": { "$ref": "#/schemas/flightStatus" },
      "actions": ["com.example.flight.checkIn"]
    }
  ],
  "actions": [
    {
      "id": "com.example.flight.checkIn",
      "paramsSchema": { "type": "object", "properties": { "confirmation": { "type": "string" } } },
      "resultSchema": { "type": "object", "properties": { "ok": { "type": "boolean" } } }
    }
  ]
}
```

### ProviderInstance

A configured running (or runnable) copy of a manifest.

| Field | Description |
| ----- | ----------- |
| `id` | Stable instance id (`inst_…`) |
| `manifestId` / `manifestVersion` | Package identity |
| `config` | User settings (non-secret) |
| `secretRefs` | Map of config keys → secret store ids |
| `restartPolicy` | Optional override |
| `state` | Lifecycle state ([03](03-provider-lifecycle.md)) |

### ItemId

Stable identity: `providerInstanceId + localId`.

```json
{
  "providerInstanceId": "inst_flight_1",
  "localId": "AA100"
}
```

String form (canonical): `inst_flight_1:AA100`.

### Item

```json
{
  "id": { "providerInstanceId": "inst_flight_1", "localId": "AA100" },
  "type": "com.example.flight.status",
  "revision": 42,
  "updatedAt": "2026-08-04T20:00:00Z",
  "payload": { "flightNumber": "AA100", "status": "boarding", "gate": "B12" },
  "render": { "schemaVersion": "1.0", "root": { "type": "Text", "value": "AA100 · Gate B12" } },
  "actions": ["com.example.flight.checkIn"],
  "tags": ["travel", "today"],
  "ttl": "PT6H",
  "priority": 10,
  "asOf": "2026-08-04T20:00:00Z",
  "staleAfter": "2026-08-04T20:15:00Z"
}
```

| Field | Required | Notes |
| ----- | -------- | ----- |
| `id` | yes | Stable |
| `type` | yes | Namespaced; must be in manifest `itemTypes` |
| `revision` | yes | Monotonic per item (uint64); sync LWW key |
| `updatedAt` | yes | ISO-8601 |
| `payload` | yes | Validated JSON; opaque to Core semantics |
| `render` | no | Inline RenderDocument ([05](05-rendering-schema.md)) |
| `actions` | no | Declared action ids |
| `tags` | no | For subscriptions / boards |
| `ttl` | no | Hint for eviction |
| `priority` | no | Ordering hint for surfaces |
| `asOf` / `staleAfter` | no | Freshness metadata ([15](15-offline-behavior.md)) |

### Snapshot / Delta

```json
{
  "snapshot": {
    "providerInstanceId": "inst_flight_1",
    "items": [ "/* Item[] full replace for instance scope */" ]
  }
}
```

```json
{
  "delta": {
    "providerInstanceId": "inst_flight_1",
    "upsert": [ "/* Item[] */" ],
    "delete": [ { "providerInstanceId": "inst_flight_1", "localId": "AA200" } ]
  }
}
```

Rules:

1. Snapshot replaces all items for the instance (or declared scope).
2. Delta upserts by `ItemId`; deletes remove by id.
3. Upsert with `revision <=` stored revision **shall** be ignored (monotonicity).

### RenderDocument

See [05-rendering-schema.md](05-rendering-schema.md). May be attached to an Item (`item.render`) or to a BoardSurface region.

### Action / ActionInvocation

See [07-action-system.md](07-action-system.md). Actions are declared on the manifest (and optionally referenced from items).

### Event

Typed bus messages — catalog in [06-event-system.md](06-event-system.md).

### Subscription

Client interest filter:

```json
{
  "id": "sub_1",
  "types": ["com.example.flight.status"],
  "tagsAny": ["today"],
  "providerInstanceIds": ["inst_flight_1"]
}
```

### BoardSurface

User-owned layout: which items/regions map to which renderer slots. **Not** provider-owned.

```json
{
  "id": "surface_home",
  "schemaVersion": "1.0",
  "slots": [
    {
      "slotId": "widget.medium.1",
      "surfaceHint": "widgetMedium",
      "binding": {
        "kind": "itemQuery",
        "types": ["com.example.flight.status"],
        "tagsAny": ["pinned"],
        "limit": 1
      }
    }
  ]
}
```

## Principle: opaque-but-validated payloads

```
Provider registers:  com.example.flight.status → JSON Schema
Core stores:         payload as JSON blob after validation
Core queries:        by type, tags, ids, revision — never by payload.gate
Renderer:            prefers item.render; may use typed payload only via future client-side plugins (non-goal for Core)
```

## Normative rules

1. Item types **shall** be reverse-DNS namespaced.
2. `ItemId.localId` **shall** be stable across revisions for the same real-world entity.
3. Core **shall** reject items whose `type` is not registered on the instance manifest.
4. BoardSurfaces **shall** be synced as user state, not as provider items ([14](14-synchronization.md)).

## Non-goals

- Graph database or arbitrary joins across provider payloads in Core
- Core-side derived items that invent domain facts
- HTML or MIME body storage as a first-class Item substitute for Render IR

## Tradeoffs

Opaque payloads keep Core lean and multi-provider safe; the cost is that cross-provider “smart” queries require tags, types, or a future explicit indexing API — not ad-hoc JSON path queries in v1.

## Related

- [05-rendering-schema.md](05-rendering-schema.md)
- [08-plugin-protocol.md](08-plugin-protocol.md)
- [14-synchronization.md](14-synchronization.md)
