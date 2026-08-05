# 06 — Event System

## Purpose

Specify the in-process Event Bus in Core, how providers emit OPP notifications, and how clients subscribe over the Client Protocol.

## Architecture

```
Provider --OPP notifications--> Supervisor --> EventBus --> Client Protocol subscribers
                                      │
                                      └── persist side effects (items) then emit
```

Events are **typed**, **immutable** facts about state changes. They are not a general RPC substitute.

## Event envelope

```json
{
  "id": "evt_01JABC…",
  "type": "item.changed",
  "ts": "2026-08-04T20:00:00.123Z",
  "source": {
    "kind": "provider",
    "providerInstanceId": "inst_flight_1"
  },
  "payload": {}
}
```

## Catalog (Core EventBus)

| Type | Emitted when | Payload (summary) |
| ---- | ------------ | ----------------- |
| `item.changed` | Item upserted | `{ id, revision, type }` |
| `item.deleted` | Item deleted | `{ id }` |
| `items.snapshotApplied` | Full snapshot replaced instance items | `{ providerInstanceId, count }` |
| `provider.lifecycle` | Lifecycle transition | `{ instanceId, from, to, reason }` |
| `provider.status` | Provider status notification | `{ instanceId, state, reasonCode? }` |
| `provider.log` | Provider log line (debug) | `{ instanceId, level, message }` |
| `action.started` | Action invocation accepted | `{ invocationId, actionId }` |
| `action.completed` | Action finished ok | `{ invocationId, result }` |
| `action.failed` | Action failed | `{ invocationId, error }` |
| `action.followUp` | Interactive follow-up required | `{ invocationId, followUp }` |
| `sync.progress` | Sync domain activity | `{ domain, phase }` |
| `sync.conflict` | Conflict needing user resolution | `{ domain, conflictId }` |
| `permission.changed` | User grant/revoke | `{ instanceId, permissionId, granted }` |
| `render.invalid` | Soft IR validation issue | `{ itemId?, issues[] }` |

## OPP notifications → bus

| OPP method | Bus event(s) |
| ---------- | ------------ |
| `items/changed` | `item.changed` / `item.deleted` / `items.snapshotApplied` |
| `provider/status` | `provider.status` (+ lifecycle if state maps) |
| `log` | `provider.log` |

Providers **do not** publish arbitrary bus types; they use the OPP notification catalog ([08](08-plugin-protocol.md)).

## Client subscriptions

Clients register filters (see `Subscription` in [04](04-data-model.md)) plus event-type interest:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "events/subscribe",
  "params": {
    "types": ["item.changed", "provider.status", "action.followUp"],
    "subscription": {
      "types": ["com.example.flight.status"],
      "tagsAny": ["pinned"]
    }
  }
}
```

Delivery is push over Client Protocol. Replay of missed events is **best-effort** via `events/replay` from a cursor; durable truth remains SQLite item state, not the event log (v1 does not require infinite event retention).

## Normative rules

1. Item mutations **shall** be committed to SQLite before corresponding `item.*` events are visible to clients.
2. Event payloads **shall** be telemetry-safe (no secrets, no full tokens).
3. High-volume `provider.log` **may** be rate-limited or dropped under pressure; item events must not.
4. Hub and local Core share the same event type catalog; Hub may additionally fan-out to Sync Protocol observers.

## Ordering

- Per `providerInstanceId`, item events retain causal order for a single supervisor stream.
- Cross-instance ordering is not guaranteed.
- Clients **shall** treat EventBus as a hint and reconcile with store reads when building UI.

## Non-goals

- Exactly-once distributed delivery across devices (sync is a separate path — [14](14-synchronization.md))
- CEP / complex event processing in Core
- Providers subscribing to other providers’ events in v1

## Tradeoffs

Ephemeral events keep Core simple; clients that disconnect rely on item snapshots rather than a Kafka-like log. This favors offline-first item state over event sourcing.

## Related

- [07-action-system.md](07-action-system.md)
- [08-plugin-protocol.md](08-plugin-protocol.md)
- [09-ipc-protocol.md](09-ipc-protocol.md)
