# 02 — Core Responsibilities

## Purpose

Define what OmniBoard Core owns, what it deliberately does not own, and the invariants that keep providers and renderers loosely coupled.

## What Core owns

| Subsystem | Responsibility |
| --------- | -------------- |
| **ItemStore** | SQLite persistence of Items, RenderDocuments, revisions, provider instance metadata |
| **Render IR adapter** | Validate RenderDocuments against the IR schema; strip/degrade unknown nodes per policy |
| **ProviderSupervisor** | Install/configure/start/stop/uninstall; restart policies; health probes |
| **PermissionBroker** | Enforce manifest-declared capabilities against user grants |
| **ActionRouter** | Validate invocations, check permissions, forward `actions/execute`, return results |
| **EventBus** | In-process typed events; fan-out to Client Protocol subscribers |
| **CacheLayer** | Core-tier item/render caches; honor provider cache hints; feed renderer snapshot caches |
| **SyncEngine** | Optional Hub sync for items, user state, and provider config (split domains) |
| **Secret broker** | Store secret refs in OS keychain / Hub store; inject ephemeral credentials |
| **BoardSurface store** | Persist user layouts mapping items/regions → renderer slots |

## What Core must never do

1. **Interpret domain fields** inside provider payloads (no `if flight.status == "delayed"` in Core).
2. **Call third-party APIs** on behalf of a domain (GitHub, airlines, weather) — that is provider work.
3. **Render UI** — Core validates and stores IR; SwiftUI renderers paint.
4. **Load in-process native plugins** in v1 — providers are out-of-process only.
5. **Require Hub** for local operation or phone home for telemetry by default.
6. **Persist provider secrets in plaintext** or hand long-lived secrets to disk under provider control.

## Invariants

```
Provider  --OPP-->  Core  --Client Protocol-->  Renderer
              │
              ├── validates schemas & Render IR
              ├── enforces permissions
              └── persists last-good state
```

- Every Item has a stable `ItemId` scoped to a `ProviderInstance` ([04](04-data-model.md)).
- Every RenderDocument has a `schemaVersion`; Core accepts N and documents N−1 compatibility for renderers ([05](05-rendering-schema.md), [17](17-versioning.md)).
- Provider crashes **must not** crash Core; UI shows last-good data + error chip ([16](16-error-handling.md)).

## Hub vs local Core

Hub is **headless Core** plus deploy-oriented services:

| Capability | Local Core | Hub |
| ---------- | ---------- | --- |
| ItemStore / EventBus / OPP host | Yes | Yes |
| SwiftUI clients attached | Yes | No |
| Scheduler / inbound webhooks | Optional / light | Primary |
| Multi-device aggregation | Via Sync client | Via Sync server |
| Secret store | OS keychain | Encrypted secret store |

Shared code path is mandatory; packaging differs (`core/` vs `hub/` deployables) — see [19](19-repository-layout.md).

## Normative rules

1. Core **shall** treat registered payload schemas as validation-only contracts.
2. Core **shall** supervise providers and isolate failures per instance.
3. Core **shall** expose Client Protocol read APIs that work entirely from local SQLite when offline.
4. Core **shall not** embed provider-specific UI templates; BoardSurfaces are user-owned layout, not domain knowledge.

## Concrete example — Core path for an item update

```json
{
  "jsonrpc": "2.0",
  "method": "items/changed",
  "params": {
    "providerInstanceId": "inst_flight_1",
    "delta": {
      "upsert": [
        {
          "id": { "providerInstanceId": "inst_flight_1", "localId": "AA100" },
          "type": "com.example.flight.status",
          "revision": 42,
          "updatedAt": "2026-08-04T20:00:00Z",
          "payload": { "flightNumber": "AA100", "status": "boarding" },
          "render": {
            "schemaVersion": "1.0",
            "root": {
              "type": "HStack",
              "children": [
                { "type": "Text", "value": "AA100" },
                { "type": "Text", "value": "Boarding" }
              ]
            }
          }
        }
      ],
      "delete": []
    }
  }
}
```

Core steps: authenticate channel → validate `type` against manifest → validate `render` → upsert SQLite → emit `item.changed` on EventBus → invalidate caches as needed.

## Non-goals

- Becoming a general workflow engine or IFTTT replacement
- Multi-tenant SaaS control plane beyond Hub sync/hosting
- Domain-specific business rules in Core

## Tradeoffs

Keeping Core domain-agnostic increases provider freedom and multi-surface consistency, at the cost of needing a strong Render IR and schema registry instead of hard-coded templates.

## Related

- [01-system-overview.md](01-system-overview.md)
- [03-provider-lifecycle.md](03-provider-lifecycle.md)
- [08-plugin-protocol.md](08-plugin-protocol.md)
