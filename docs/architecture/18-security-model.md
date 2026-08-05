# 18 — Security Model

## Purpose

Document the threat model, trust boundaries, and mitigations for OmniBoard’s multi-provider, local-first design.

## Trust boundaries

| Zone | Trust |
| ---- | ----- |
| Core | Trusted computing base on device / Hub |
| Apple renderers | Trusted as first-party; still mediate via Client Protocol |
| Providers | **Untrusted** — may be third-party |
| Hub | Trusted by enrolled devices; still enforces per-tenant isolation later |
| Third-party APIs | Untrusted networks |

## Threat model (abridged)

| Threat | Mitigation |
| ------ | ---------- |
| Malicious provider exfiltrates data | Process isolation; network host allowlists; FS jail; no default `shell` ([12](12-permissions.md)) |
| Provider crashes Core | Out-of-process only; Rust Core memory safety |
| Secret theft from disk | Keychain / encrypted Hub store; ephemeral injection; no secret persistence by providers ([11](11-authentication.md)) |
| Supply-chain trojan provider package | Signed packages; hashed manifests; optional notarization path for the app itself |
| Compromised renderer extension | Client Protocol least privilege; no OPP exposure |
| MITM on Hub sync | TLS; device identity; authenticated channels |
| Confused deputy (action abuse) | Manifest-declared actions; permission checks; user confirm for destructive/follow-ups |
| Log leakage | Redaction; telemetry-safe error data ([16](16-error-handling.md)) |
| Widget timeline poisoning via IR | Schema validation; degrade unknown nodes; no script in IR ([05](05-rendering-schema.md)) |

## Process isolation

v1 design: **no in-process native plugins**. Every provider is a supervised process speaking OPP ([09](09-ipc-protocol.md)).

## Package integrity

1. Provider packages include manifest + payload + signature metadata.
2. Core verifies hash/signature before install.
3. Upgrade requires signature check and permission re-consent on privilege expansion.
4. Apple distribution notarization applies to OmniBoard app binaries, not necessarily every third-party provider (documented distinction).

## Hub-specific

- Encrypt secrets at rest.
- Authenticate every Sync and remote OPP channel.
- Treat hosted providers with the same permission model as local.
- Avoid becoming an open relay: host allowlists still apply egress.

## Normative rules

1. Core **shall** deny undeclared network hosts.
2. Core **shall** not load unsigned provider packages when signature enforcement is enabled (default for release builds).
3. Providers **shall not** receive other instances’ items or secrets.
4. Security-sensitive changes land via RFC in `docs/rfcs/` after this baseline.

## Non-goals

- Formal verification of all providers
- Protecting the user from themselves granting `shell` after clear warnings
- Guaranteeing safety if the OS device is already rooted/jailbroken

## Residual risks

Userspace enforcement cannot perfectly constrain a native binary on all platforms without OS sandbox primitives. OmniBoard documents this limit and uses the strongest available platform mechanisms; see [21](21-risks-and-tradeoffs.md).

## Related

- [11-authentication.md](11-authentication.md)
- [12-permissions.md](12-permissions.md)
- [09-ipc-protocol.md](09-ipc-protocol.md)
