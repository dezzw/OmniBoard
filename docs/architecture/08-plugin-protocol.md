# 08 — Plugin Protocol (OPP)

## Purpose

Specify the OmniBoard Provider Protocol: LSP-style JSON-RPC 2.0 semantics with capability negotiation. OPP is how Core talks to providers regardless of language.

## Design verdict

| Option | Verdict |
| ------ | ------- |
| Language-specific in-process plugins | Rejected — couples Core to languages, crash risk, weak sandboxing |
| gRPC-first as required path | Rejected — high friction for script providers; allowed later as transport adapter |
| Raw HTTP REST only | Rejected — weak for bidirectional push, lifecycle, streaming |
| **JSON-RPC + capabilities (LSP model)** | **Chosen** |

Encoding: **JSON** is the canonical human/debug encoding. MessagePack may be negotiated via capabilities. Protobuf/gRPC may later wrap the **same semantic messages**.

## Handshake

### `initialize` (request)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "oppVersion": "1.0",
    "processId": 12345,
    "clientInfo": { "name": "omniboard-core", "version": "0.0.0" },
    "capabilities": {
      "items": { "push": true, "pull": true },
      "actions": { "execute": true },
      "cache": { "hints": true },
      "encoding": ["json", "msgpack"]
    },
    "instance": {
      "providerInstanceId": "inst_flight_1",
      "config": { "route": "JFK-LHR" },
      "locale": "en-US"
    }
  }
}
```

### `initialize` result

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "oppVersion": "1.0",
    "serverInfo": { "name": "flights", "version": "1.4.0" },
    "capabilities": {
      "items": { "push": true, "pull": false },
      "actions": { "execute": true },
      "cache": { "hints": true },
      "encoding": ["json"]
    }
  }
}
```

Then Core sends notification `initialized`. Negotiated capability set is the intersection.

## Capability identifiers

| Capability | Meaning |
| ---------- | ------- |
| `items.push` | Provider may send `items/changed` |
| `items.pull` | Core may call `items/get` / `items/query` |
| `actions.execute` | Provider handles `actions/execute` |
| `cache.hints` | Provider may attach cache directives |
| `encoding.msgpack` | Binary frames allowed after negotiation |
| `log` | Provider may emit `log` notifications |
| `provider.ping` | Health ping supported |

Unknown capabilities are ignored (forward compatible).

## Method catalog

### Requests (Client = Core, Server = Provider unless noted)

| Method | Direction | Purpose |
| ------ | --------- | ------- |
| `initialize` | Core → Provider | Handshake |
| `shutdown` | Core → Provider | Graceful stop |
| `provider/ping` | Core → Provider | Liveness |
| `items/get` | Core → Provider | Fetch by ids (if `items.pull`) |
| `items/query` | Core → Provider | Query filter (if `items.pull`) |
| `actions/execute` | Core → Provider | Run action |
| `config/updated` | Core → Provider | Push config changes |

### Notifications

| Method | Direction | Purpose |
| ------ | --------- | ------- |
| `initialized` | Core → Provider | Handshake complete |
| `items/changed` | Provider → Core | Snapshot or delta |
| `provider/status` | Provider → Core | ready / degraded / stopping |
| `log` | Provider → Core | Structured log line |
| `exit` | Provider → Core | About to exit (optional) |

## `items/changed` shape

```json
{
  "jsonrpc": "2.0",
  "method": "items/changed",
  "params": {
    "providerInstanceId": "inst_flight_1",
    "delta": {
      "upsert": [ { "id": { "providerInstanceId": "inst_flight_1", "localId": "AA100" }, "type": "com.example.flight.status", "revision": 42, "updatedAt": "2026-08-04T20:00:00Z", "payload": {} } ],
      "delete": []
    },
    "cache": { "ttlMs": 60000, "tags": ["flights"] }
  }
}
```

## Error codes

JSON-RPC reserved codes plus OPP application codes (see also [16](16-error-handling.md)):

| Code | Name | Meaning |
| ---- | ---- | ------- |
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid request | Bad envelope |
| -32601 | Method not found | Unknown method |
| -32602 | Invalid params | Schema failure |
| -32603 | Internal error | Provider bug |
| -32000 | ProviderCrash | Supervised crash surface |
| -32001 | Timeout | Deadline exceeded |
| -32002 | AuthExpired | Re-auth required |
| -32003 | PermissionDenied | Missing grant / allowlist |
| -32004 | InvalidRender | IR rejected hard |
| -32005 | RateLimited | Includes `retryAfterMs` |
| -32006 | StaleData | Provider knows data is stale |
| -32007 | Unavailable | Temporary outage |

## Manifest binding

The on-disk / package `ProviderManifest` ([04](04-data-model.md)) **shall** match capabilities advertised at `initialize`. Core **shall** refuse to enable undeclared permissions even if the process requests them at runtime.

## Normative rules

1. Messages **shall** be JSON-RPC 2.0 objects; batch arrays are optional and off by default.
2. Providers **shall** not speak Client Protocol or Sync Protocol.
3. Secrets **shall** arrive via secure injection ([11](11-authentication.md)), not as long-lived values in `config`.
4. Golden fixtures in `packages/protocol/` (later) are the conformance source of truth ([17](17-versioning.md)).

## Non-goals

- Mandating protobuf in v1
- Bidirectional provider-to-provider OPP
- Embedding a full LSP feature set (text sync, etc.)

## Tradeoffs

JSON-RPC maximizes authoring accessibility and transport flexibility; strong typing relies on external JSON Schemas and conformance tests rather than IDL codegen alone.

## Related

- [09-ipc-protocol.md](09-ipc-protocol.md)
- [10-transport-abstraction.md](10-transport-abstraction.md)
- [03-provider-lifecycle.md](03-provider-lifecycle.md)
