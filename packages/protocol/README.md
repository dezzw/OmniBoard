# OmniBoard Protocol（Phase 0）

OmniBoard 是实时信息运行时，不是仪表盘。本目录是 **唯一规范来源**：JSON Schema（draft 2020-12）与 golden fixtures；SDK 不是真相源。

## 路径清单

```
packages/protocol/
  README.md
  schemas/
    item/item.schema.json
    item/presentation.schema.json
    item/action.schema.json
    opp/jsonrpc.schema.json
    opp/initialize.schema.json
    opp/initialized.schema.json
    opp/items-snapshot.schema.json
    opp/items-changed.schema.json
    opp/actions-execute.schema.json
    opp/provider-status.schema.json
    opp/shutdown.schema.json
    opp/log.schema.json
    opp/manifest.schema.json
    board/board-surface.schema.json
    client/methods.schema.json
    sync/item-lww.schema.json
    sync/board-crdt-state.schema.json
  fixtures/
    …（各域 valid / invalid golden 样例）
```

## 核心约束

- **Core 无领域知识**：不得根据 `Item.type`、`Item.kind` 或 `Item.payload` 的键分支或解释语义；payload 为 Provider 不透明对象，**不得**用于布局决策。
- **Kind 是一等公民**：`Item.kind` 枚举 `notice | metric | progress | countdown`；`presentation` 由 kind 驱动，无自由布局树。
- **统一 Presentation**：同一 `presentation` 供 Board、Widget、Live Activity、Dynamic Island 使用；密度裁剪由渲染器负责，不在 schema DSL 中表达。
- **Provider 进程外**：通过 OPP（JSON-RPC 2.0）通信；默认通道为 **stdio + NDJSON**。
- **OPP 方法名（精确）**：`initialize`、`initialized`、`items/snapshot`、`items/changed`、`actions/execute`、`shutdown`、`provider/status`、`$/log`。
- **Client Phase 2 方法**：`board/get`（仅 BoardSurface，无嵌入 Item）、`items/get`、`events/subscribe`（仅 `item.updated` / `item.removed`）。`actions/execute` 属于 OPP，不在 Client 方法集内。
- **Sync schema**：`sync/item-lww` 与 `sync/board-crdt-state` 仅描述状态形状；合并代数由后续 RFC 定义。

## Item 与 Presentation

| 字段 | 说明 |
|------|------|
| `schemaVersion` | 可选，省略视为 `1`；Phase 0 接受集 `{1}` |
| `kind` | `notice`、`metric`、`progress`、`countdown` |
| `presentation` | 共享字段 `title`（必填）、`subtitle?`、`symbol?`、`badge?`；kind 专有字段见 `presentation.schema.json` |
| `actions?` | 仅 App default surface；`Action` 保持 `{ id, label }` |
| `payload` | 必须为 object；Core 不得读取其键做布局 |

**已移除**：自由 Render IR 树（`render` 字段、`render-document`、`node` schema 及对应 fixtures）。

## Fixtures 为真相源

`fixtures/` 下的 valid 与 invalid JSON 是 conformance 的 golden 依据。后续 **Rust 与 Swift 两套独立解析器** 必须：

1. 接受全部 **valid** fixtures；
2. 拒绝全部 **invalid** fixtures（每条 invalid 对应一条真实 schema 规则）。

本 Phase 0 PR **不实现** 解析器或校验 CLI；仅交付 schema 与 fixtures。

## Board 布局

- `BoardSurface.schemaVersion` 固定为 `1`；`columns.phone = 2`，`columns.pad = 4`。
- Widget 尺寸：`small` 1×1，`medium` 2×1，`large` 2×2。

## 变更流程

协议变更请使用 [`docs/rfcs/0000-template.md`](../../docs/rfcs/0000-template.md) 提交 RFC，并同步更新 schema 与 fixtures。
