# 10 — Transport Abstraction

## Purpose

Keep three layers distinct so OmniBoard can swap codecs and channels without rewriting business logic or fracturing provider SDKs.

## Three layers

```
┌─────────────────────────────────────────┐
│ 1. Semantic messages                    │
│    OPP / Client Protocol / Sync Protocol│
│    methods, params, error codes         │
├─────────────────────────────────────────┤
│ 2. Codec                                │
│    JSON (canonical) / MessagePack / …   │
├─────────────────────────────────────────┤
│ 3. Channel                              │
│    stdio / Unix / TCP / WebSocket / XPC │
│    future: gRPC adapter                 │
└─────────────────────────────────────────┘
```

### 1. Semantic messages

- Defined by catalogs in [08](08-plugin-protocol.md), Client Protocol (renderer docs later), and [14](14-synchronization.md).
- Independent of bytes and sockets.
- Versioned via `oppVersion` / protocol major.minor + capabilities ([17](17-versioning.md)).

### 2. Codec

| Codec | Role |
| ----- | ---- |
| JSON | Canonical; human/debuggable; default |
| MessagePack | Optional; negotiated capability; same object model |
| Protobuf | Future encoding of the **same** semantic messages; not a parallel API |

Rules:

1. JSON Schema / golden fixtures describe the semantic JSON shape.
2. MessagePack mapping **shall** be a mechanical transform of that shape.
3. Codecs **must not** invent new methods.

### 3. Channel

| Channel | Typical protocol |
| ------- | ---------------- |
| stdio | OPP local |
| Unix socket | OPP local / Hub sidecar |
| TCP (+TLS) | Hub remote providers / Sync |
| WebSocket | Sync / remote OPP |
| XPC | Client Protocol on Apple |
| gRPC | Future **adapter** carrying semantic messages |

## Same semantics everywhere

A Hub-hosted TypeScript provider and a local Python provider speak the same OPP methods. Only channel security (TLS, auth) and latency differ.

```
Local:   Core --stdio/JSON--> Provider
Hub:     HubCore --TLS/WebSocket/JSON--> Provider
Future:  Core --gRPC adapter--> Provider  (semantic messages unchanged)
```

## Mapping example

Semantic:

```json
{ "jsonrpc": "2.0", "method": "provider/status", "params": { "state": "ready" } }
```

- Codec JSON + channel stdio → Content-Length frame with UTF-8 body
- Codec MessagePack + channel Unix → Content-Length frame with binary body
- Future gRPC → `Notification` RPC with `method` + `params` bytes

## Normative rules

1. Documentation and SDKs **shall** refer to semantic methods first; channel details are binding only in IPC docs.
2. Introducing a new channel **shall not** require a new provider API surface.
3. gRPC, if added, **shall** be documented as a transport adapter, not a second protocol.
4. Client Protocol, OPP, and Sync Protocol **shall** remain separate semantic catalogs even if they share codec/channel libraries.

## Non-goals

- One universal socket that mixes OPP and Sync without demux
- Allowing providers to negotiate arbitrary undocumented codecs
- Making XPC available to third-party providers (Apple renderers only)

## Tradeoffs

Strict layering adds a thin abstraction cost and more docs, but prevents the classic failure mode where “the HTTP API” and “the local API” drift.

## Related

- [08-plugin-protocol.md](08-plugin-protocol.md)
- [09-ipc-protocol.md](09-ipc-protocol.md)
- [14-synchronization.md](14-synchronization.md)
