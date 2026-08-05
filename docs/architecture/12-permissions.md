# 12 — Permissions

## Purpose

Define the capability model declared in provider manifests, user grant UX, and Core enforcement (network allowlists, path jail, discouraged shell).

## Model

Permissions are **manifest-declared**, **user-granted** at install/upgrade, and **enforced by Core** (and OS sandbox where available).

```json
{
  "permissions": [
    {
      "id": "network.hosts",
      "hosts": ["api.github.com", "*.github.com"],
      "optional": false
    },
    {
      "id": "fs.read",
      "paths": ["~/Documents/OmniBoard/Inbox"],
      "optional": true
    },
    {
      "id": "notifications",
      "optional": true
    },
    {
      "id": "clipboard",
      "optional": true
    },
    {
      "id": "background.refresh",
      "optional": true
    },
    {
      "id": "shell",
      "optional": true,
      "discouraged": true
    }
  ]
}
```

## Permission identifiers

| Id | Effect |
| -- | ------ |
| `network.hosts` | Outbound network limited to listed hosts/patterns |
| `fs.read` | Read access jailed to listed paths |
| `fs.write` | Write access jailed to listed paths (rare; explicit) |
| `notifications` | May request user notifications via Core |
| `clipboard` | Read/write clipboard via Core-mediated API |
| `background.refresh` | May schedule background wake / Hub cron |
| `shell` | Execute subprocess shells — **disabled by default**, discouraged, high friction grant |

## Grant lifecycle

1. **Install:** Core presents required vs optional permissions; required must be accepted to enable.
2. **Upgrade:** New permissions trigger re-consent; removed permissions drop grants.
3. **Runtime:** Denial → `PermissionDenied` errors; provider should enter `Degraded`, not crash-loop ([03](03-provider-lifecycle.md)).
4. **Revoke:** User can revoke optional grants anytime; Core emits `permission.changed`.

## Enforcement

| Permission | Enforcement strategy |
| ---------- | -------------------- |
| `network.hosts` | OS firewall / Network Extension / userspace proxy; deny by default |
| `fs.*` | Chroot-like jail directory + allowlist checks on mediated FS APIs |
| `notifications` | Only via Core Client APIs; provider cannot post directly |
| `clipboard` | Mediated Core RPC |
| `shell` | Binary policy off unless grant; still command allowlists if ever enabled |
| `background.refresh` | Core/Hub scheduler gates |

Providers that “bring their own” unrestricted HTTP stacks **shall** still be constrained by OS-level controls where Core can apply them; documented limitation: pure userspace cannot always police every syscall — see [18](18-security-model.md).

## Action permission gates

Actions may list required permission ids ([07](07-action-system.md)). Core checks grants before `actions/execute`.

## Normative rules

1. Undeclared permissions **shall not** be grantable.
2. `shell` **shall** default to denied on all installs.
3. Host allowlists **shall** support exact hosts and a single leading `*.` wildcard label only (no arbitrary regex in v1).
4. Permission prompts **shall** show human-readable host/path lists, not only ids.

## Example deny error

```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "error": {
    "code": -32003,
    "message": "PermissionDenied",
    "data": {
      "permissionId": "network.hosts",
      "host": "evil.example",
      "userVisibleMessage": "This provider is not allowed to contact evil.example."
    }
  }
}
```

## Non-goals

- Full mandatory access control for arbitrary native code without OS help
- Crowdsourced permission reputation network in v1
- Automatic grant of `shell` for “developer mode” without explicit user action

## Tradeoffs

Fine-grained host allowlists are slightly annoying for providers with many CDNs, but they are the primary practical control for supply-chain damage containment.

## Related

- [11-authentication.md](11-authentication.md)
- [18-security-model.md](18-security-model.md)
- [08-plugin-protocol.md](08-plugin-protocol.md)
