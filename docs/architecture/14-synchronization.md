# 14 — Synchronization

## Purpose

Define multi-device sync with **split domains**: provider-authoritative items, CRDT-style user state, and versioned provider config with user resolution on conflict. Hub is optional.

## Domains

| Domain | Authority | Merge strategy |
| ------ | --------- | -------------- |
| **Items** | Provider instance | Monotonic `revision` per item; LWW by revision; Hub merges by instance ownership |
| **User state** | User devices | CRDT-style document (Automerge or equivalent): pins, dismissals, BoardSurfaces |
| **Provider config** | User | Versioned documents; conflict → user resolution UI |

Do **not** put all three in one global CRDT ([21](21-risks-and-tradeoffs.md)).

## Items sync

```
Device A Core ◄──Sync Protocol──► Hub ◄──Sync Protocol──► Device B Core
                 │
                 └── may also host provider instance
```

Rules:

1. Each Item belongs to exactly one `providerInstanceId`.
2. Hub accepts upserts only from the owner (device or Hub-hosted supervisor) for that instance, unless explicitly delegated.
3. Compare `revision` (uint64); higher wins; equal revision → compare `updatedAt` then deterministic tie-break on payload hash.
4. Deletes carry a revision tombstone until compaction.
5. Stale writes with lower revision are ignored and **may** emit `sync.progress` diagnostics.

### Wire sketch

```json
{
  "jsonrpc": "2.0",
  "method": "sync/items/push",
  "params": {
    "providerInstanceId": "inst_flight_1",
    "delta": { "upsert": [], "delete": [] }
  }
}
```

## User state sync

Document types include:

- Pins / favorites
- Dismissals / snoozes
- BoardSurfaces and slot bindings
- UI preferences that must roam

Properties:

1. Concurrent edits merge without user prompts when CRDT semantics allow.
2. Sync is independent of whether providers are online.
3. Local-only mode: CRDT stays on-device; no Hub required.

## Provider config sync

```json
{
  "instanceId": "inst_flight_1",
  "configVersion": 7,
  "config": { "route": "JFK-LHR" },
  "secretRefs": { "apiToken": "secret:…" }
}
```

Rules:

1. Secret **values** are not synced in plaintext; Hub uses its secret store; devices sync refs + encrypted secret payloads under Hub crypto when enabled.
2. Conflicting `configVersion` graphs → `sync.conflict` event; UI picks a winner or merges field-wise.
3. Config apply triggers OPP `config/updated` on the owning supervisor.

## Sync Protocol vs OPP

Sync Protocol is Core↔Hub (and Core↔Core via Hub). Providers never speak Sync Protocol; they continue to use OPP against whichever Core hosts them.

## Normative rules

1. Item sync **shall not** rewrite `payload` shape; validation remains against the owner manifest.
2. User-state CRDT **shall not** embed full Item payloads (ids and layout only).
3. Local Core **shall** function with sync disabled.
4. Hub **shall** run the same ItemStore semantics as local Core for hosted instances.

## Non-goals

- Real-time collaborative editing of Render IR trees across users
- Peer-to-peer mesh without Hub in v1
- Automatically merging divergent provider config without user input

## Tradeoffs

Split domains increase conceptual surface area but avoid CRDT complexity on high-churn provider items and avoid LWW data loss on user layout edits.

## Related

- [04-data-model.md](04-data-model.md)
- [13-caching.md](13-caching.md)
- [15-offline-behavior.md](15-offline-behavior.md)
