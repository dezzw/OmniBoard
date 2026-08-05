# 05 — Rendering Schema (Render IR)

## Purpose

Define the declarative Render IR: a versioned JSON tree of semantic components that providers emit and SwiftUI renderers consume. Providers describe **what**; Core validates; renderers decide **how** per surface.

## Design rules

1. **No** pixel layout, SwiftUI types, HTML, or CSS.
2. **Semantic** components only (`Text`, `HStack`, `Gauge`, …).
3. **Surface hints** and density switches adapt one document to many Apple surfaces.
4. **Unknown nodes** degrade via `fallback` children or omission — never crash the renderer.
5. Renderers implement schema versions **N and N−1** ([17](17-versioning.md)).

## Document envelope

```json
{
  "schemaVersion": "1.0",
  "surfaceHints": ["widgetMedium", "lockScreen"],
  "localization": { "locale": "en-US", "defaultTable": "FlightProvider" },
  "root": {
    "type": "VStack",
    "children": []
  }
}
```

| Field | Required | Notes |
| ----- | -------- | ----- |
| `schemaVersion` | yes | Major.minor string |
| `root` | yes | Component node |
| `surfaceHints` | no | Preferred surfaces this document targets |
| `localization` | no | Keys resolved by renderer |

## Surface hints

| Hint | Typical consumer |
| ---- | ---------------- |
| `lockScreen` | Lock screen widget / glance |
| `widgetSmall` | WidgetKit small |
| `widgetMedium` | WidgetKit medium |
| `widgetLarge` | WidgetKit large |
| `liveActivity` | ActivityKit banner |
| `dynamicIsland` | Dynamic Island compact/expanded |
| `menuBar` | macOS menu bar extra |
| `watchComplication` | watchOS complication |
| `canvas` | Main app canvas / detail |

Hints are advisory. BoardSurfaces bind slots to hints ([04](04-data-model.md)). Platform budget limits may force Core-side snapshot materialization — adapters own that, not providers ([21](21-risks-and-tradeoffs.md)).

## Component vocabulary (v1)

| Type | Role | Key fields |
| ---- | ---- | ---------- |
| `Text` | String or localization key | `value`, `key`, `style` (`title`\|`body`\|`caption`\|`mono`) |
| `Symbol` | SF Symbol name | `name`, `accessibilityLabel` |
| `Image` | Remote/local image ref | `uri`, `contentMode` |
| `HStack` / `VStack` | Linear layout | `children`, `spacing`, `alignment` |
| `Grid` | Simple grid | `children`, `columns` |
| `List` | Vertical collection | `children` |
| `Gauge` | Scalar in range | `value`, `min`, `max`, `label` |
| `Progress` | Determinate/indeterminate | `value?`, `label` |
| `RelativeTime` | Instant → relative string | `instant` |
| `Sparkline` | Small numeric series | `points[]` |
| `Conditional` | Predicate switch | `when`, `then`, `else` |
| `SizeClassSwitch` | Density / size branch | `compact`, `regular`, … |
| `SurfaceSwitch` | Branch by surface hint | `cases{ hint: node }`, `default` |
| `ActionButton` | Invokes declared action | `actionId`, `label`, `params` |
| `Fallback` | Explicit degrade wrapper | `primary`, `fallback` |

### Common node fields

Every node may include:

```json
{
  "type": "Text",
  "value": "Boarding",
  "id": "status",
  "accessibility": { "role": "header", "label": "Flight status" },
  "fallback": { "type": "Text", "value": "Status unavailable" }
}
```

## Example — flight status for widget + island

```json
{
  "schemaVersion": "1.0",
  "surfaceHints": ["widgetMedium", "dynamicIsland"],
  "root": {
    "type": "SurfaceSwitch",
    "cases": {
      "dynamicIsland": {
        "type": "HStack",
        "children": [
          { "type": "Symbol", "name": "airplane", "accessibilityLabel": "Flight" },
          { "type": "Text", "value": "AA100", "style": "title" }
        ]
      },
      "widgetMedium": {
        "type": "VStack",
        "children": [
          {
            "type": "HStack",
            "children": [
              { "type": "Text", "value": "AA100", "style": "title" },
              { "type": "Text", "value": "Gate B12", "style": "body" }
            ]
          },
          { "type": "RelativeTime", "instant": "2026-08-04T21:30:00Z" },
          {
            "type": "ActionButton",
            "actionId": "com.example.flight.checkIn",
            "label": { "key": "action.checkIn" }
          }
        ]
      }
    },
    "default": { "type": "Text", "value": "AA100" }
  }
}
```

## Validation and degradation

Core **shall**:

1. Reject documents that fail the IR JSON Schema for the declared `schemaVersion` when the root is invalid.
2. For unknown **optional** fields: strip and keep.
3. For unknown **node types**: replace with `fallback` if present; otherwise omit the node and log `InvalidRender` soft warning.
4. Never throw through to WidgetKit timelines — materialize a safe placeholder component if the entire tree collapses.

Renderers **shall** implement the same degrade rules for forward-compatible documents.

## Why not alternatives

| Alternative | Why rejected |
| ----------- | ------------ |
| Providers return SwiftUI | Breaks sandboxing, Watch/widgets, Hub; couples to Apple UI kit |
| Providers return HTML | Poor for complications/islands; security surface; inconsistent native feel |
| Raw data + client-only templates | Forces Core/UI to know every domain; stalls third-party providers |

Render IR is the stable middle ground (unified semantic display, formalized).

## Non-goals

- Pixel-perfect parity across all surfaces
- Full layout language (flexbox clone)
- Animation timelines as a provider concern (renderers may animate appearance only)
- Arbitrary script execution inside IR

## Tradeoffs

A small semantic vocabulary risks “ugly consistency”; a large one risks chasing SwiftUI forever. Mitigation: keep v1 vocabulary tight, publish reference design guidelines, and rely on strong fallbacks ([21](21-risks-and-tradeoffs.md)).

## Related

- [04-data-model.md](04-data-model.md)
- [07-action-system.md](07-action-system.md)
- [17-versioning.md](17-versioning.md)
