# OmniBoard 产品说明与实施计划（All-in-One）

> **本文档自包含**：不依赖其他 repo 文件、分支或外链即可阅读与实施。  
> 目标读者：产品负责人、Swift 前端、Rust 后端、Provider 作者。

---

## 目录

1. [产品是什么](#1-产品是什么)
2. [系统架构总览](#2-系统架构总览)
3. [后端：OmniBoard Core（Rust）](#3-后端omniboard-corerust)
4. [OPP：Provider 协议](#4-oppprovider-协议)
5. [Client Protocol：前端 ↔ Core](#5-client-protocol前端--core)
6. [Render IR：声明式 UI 契约](#6-render-ir声明式-ui-契约)
7. [Action 系统](#7-action-系统)
8. [前端：SwiftUI 客户端](#8-前端swiftui-客户端)
9. [端到端数据流](#9-端到端数据流)
10. [仓库结构与文件清单](#10-仓库结构与文件清单)
11. [开发环境要求](#11-开发环境要求)
12. [分阶段实施计划](#12-分阶段实施计划)
13. [近期实施 Checklist](#13-近期实施-checklist)
14. [非目标与风险](#14-非目标与风险)

---

## 1. 产品是什么

**OmniBoard** 是一款 **Apple 优先** 的个人信息面板（Personal Information Surface）。

用户在一个「Board」上看到来自多个数据源的信息卡片（航班、日历、任务、自定义插件等）。这些数据**不是** App 硬编码的，而是由 **Provider**（独立进程、任意语言）推送进来。

### 一句话架构

```
Provider（领域知识）→ Core（可信运行时）→ SwiftUI Renderer（展示）
```

### 核心原则

| 原则 | 含义 |
| ---- | ---- |
| **Provider 权威** | 领域数据与 payload schema 由 Provider 拥有；Core 只做 JSON Schema 校验，不做业务 if/else |
| **声明式 Render IR** | Provider 描述「展示什么」（语义组件树），SwiftUI 决定「怎么画」 |
| **进程隔离** | Provider 不可信；Core 负责权限、重启、失败隔离 |
| **本地优先** | SQLite 是设备端真相源；无 Hub、无网络也能用 |
| **软失败** | 未知 Render 节点降级；Provider 崩溃后 UI 仍显示 last-good 数据 |

### 实现语言（已定）

| 层 | 语言 |
| -- | ---- |
| Core + Hub | **Rust**（同一套代码，Hub = 无 UI 部署） |
| Apple 客户端 | **Swift / SwiftUI** |
| Provider | **任意语言**（通过 OPP JSON-RPC 通信） |

---

## 2. 系统架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│  前端 · Apple Renderers（Swift / SwiftUI）                        │
│  ┌─────────────┐  ┌──────────┐  ┌────────────┐  ┌────────────┐  │
│  │ iOS/macOS   │  │ WidgetKit│  │ Live       │  │ watchOS /  │  │
│  │ App         │  │          │  │ Activity   │  │ Menu Bar   │  │
│  └──────┬──────┘  └────┬─────┘  └─────┬──────┘  └─────┬──────┘  │
│         └──────────────┴──────────────┴───────────────┘          │
│                              │ Client Protocol                    │
└──────────────────────────────┼───────────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  后端 · OmniBoard Core（Rust）                                    │
│  ItemStore │ EventBus │ ActionRouter │ ProviderSupervisor        │
│  PermissionBroker │ CacheLayer │ Render IR 校验 │ SyncEngine     │
│                              │ OPP（JSON-RPC 2.0）                │
└──────────────────────────────┼───────────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Provider 进程（Python / Rust / TS / …）                          │
└─────────────────────────────────────────────────────────────────┘

        （可选，Phase 5）Sync Protocol ◄──► Hub（无头 Core + 调度/Webhook）
```

### 三条协议

| 协议 | 通信方 | 默认通道 | 职责 |
| ---- | ------ | -------- | ---- |
| **OPP** | Core ↔ Provider | stdio（也可 Unix socket / TCP） | 初始化、推送 Item、执行 Action |
| **Client Protocol** | Renderer ↔ Core | Unix socket 或 XPC | 读 Item、订阅事件、触发 Action |
| **Sync Protocol** | Core ↔ Hub | TLS / WebSocket | 多设备同步（后期） |

### 信任边界与硬性规则

```
┌─────────────────────────────────────────────────────────┐
│ Apple app sandbox                                       │
│  ┌──────────────┐    Client Protocol    ┌────────────┐  │
│  │  Renderers   │◄─────────────────────►│    Core    │  │
│  │  (SwiftUI)   │                       │  (trusted) │  │
│  └──────────────┘                       └─────┬──────┘  │
│                                               │ OPP     │
│                                         ┌─────▼──────┐  │
│                                         │ Providers  │  │
│                                         │ (untrusted)│  │
│                                         └────────────┘  │
└─────────────────────────────────────────────────────────┘
```

1. Renderer **不得** 直接调用 Provider
2. Provider **不得** 嵌入 SwiftUI、HTML 或像素布局
3. Core **不得** 解释 payload 内的领域字段（仅 schema 校验）
4. Core **不得** 调用第三方 API（GitHub、航司等）—— 那是 Provider 的事
5. v1 **不支持** 进程内原生插件
6. 无 Hub 时系统 **必须** 完整可用

---

## 3. 后端：OmniBoard Core（Rust）

### 3.1 Core 子系统

| 子系统 | 职责 |
| ------ | ---- |
| **ItemStore** | SQLite 持久化 Item、RenderDocument、revision、Provider 实例元数据 |
| **ProviderSupervisor** | 安装/配置/启停/卸载 Provider；重启策略；健康探测 |
| **Render IR Adapter** | 校验 Render IR schema；未知节点 strip 或 degrade |
| **PermissionBroker** | Manifest 声明的能力 vs 用户授权 |
| **ActionRouter** | 校验 invocation → 权限 → 转发 `actions/execute` → 返回结果 |
| **EventBus** | 进程内 typed events；fan-out 到 Client Protocol 订阅者 |
| **CacheLayer** | Item/Render 缓存；尊重 Provider cache hints；供 Widget snapshot |
| **SyncEngine** | （Phase 5）与 Hub 同步 Item 与用户状态 |
| **Secret Broker** | OS Keychain / Hub 加密存储；向 Provider 注入临时凭证 |
| **BoardSurface Store** | 用户 Board 布局：哪些 Item 出现在哪些 surface slot |

### 3.2 Core 目录结构（Rust）

```
core/
├── Cargo.toml
├── README.md
└── src/
    ├── lib.rs
    ├── bin/omniboard.rs      # CLI 入口：--socket /tmp/omniboard.sock
    ├── store.rs              # ItemStore (SQLite)
    ├── item.rs               # Item, ItemId 类型
    ├── opp.rs                # OPP JSON-RPC 处理
    ├── supervisor.rs         # Provider 进程监督
    ├── client.rs             # Client Protocol Unix socket 服务
    ├── event.rs              # EventBus
    ├── render.rs             # Render IR 校验
    ├── framing.rs            # Content-Length 帧编解码
    └── error.rs              # 错误码
```

### 3.3 数据模型

#### ProviderManifest（Provider 包静态契约）

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
  "configSchema": { "type": "object", "properties": { "route": { "type": "string" } } },
  "itemTypes": [
    {
      "type": "com.example.flight.status",
      "payloadSchema": { "type": "object", "properties": { "flightNumber": { "type": "string" } } },
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

#### ProviderInstance（已配置的 Provider 副本）

| 字段 | 说明 |
| ---- | ---- |
| `id` | 稳定实例 id，如 `inst_flight_1` |
| `manifestId` / `manifestVersion` | 包身份 |
| `config` | 用户设置（非密钥） |
| `secretRefs` | config 键 → Keychain secret id 映射 |
| `state` | 生命周期：installed / starting / ready / degraded / stopped |

#### ItemId

```json
{ "providerInstanceId": "inst_flight_1", "localId": "AA100" }
```

规范字符串形式：`inst_flight_1:AA100`

#### Item（完整示例）

```json
{
  "id": { "providerInstanceId": "inst_flight_1", "localId": "AA100" },
  "type": "com.example.flight.status",
  "revision": 42,
  "updatedAt": "2026-08-04T20:00:00Z",
  "payload": {
    "flightNumber": "AA100",
    "status": "boarding",
    "gate": "B12"
  },
  "render": {
    "schemaVersion": "1.0",
    "surfaceHints": ["widgetMedium", "canvas"],
    "root": {
      "type": "HStack",
      "children": [
        { "type": "Text", "value": "AA100", "style": "title" },
        { "type": "Text", "value": "Gate B12", "style": "body" }
      ]
    }
  },
  "actions": ["com.example.flight.checkIn"],
  "tags": ["travel", "today"],
  "ttl": "PT6H",
  "priority": 10,
  "asOf": "2026-08-04T20:00:00Z",
  "staleAfter": "2026-08-04T20:15:00Z"
}
```

| 字段 | 必填 | 说明 |
| ---- | ---- | ---- |
| `id` | ✓ | 稳定身份 |
| `type` | ✓ | 命名空间类型，须在 manifest itemTypes 中注册 |
| `revision` | ✓ | 单调递增 uint64，同步 LWW 键 |
| `updatedAt` | ✓ | ISO-8601 |
| `payload` | ✓ | 校验过的 JSON，Core 不解释语义 |
| `render` | | 内联 RenderDocument |
| `actions` | | 可用 action id 列表 |
| `tags` | | 订阅 / Board 过滤 |
| `ttl` | | 驱逐提示 |
| `asOf` / `staleAfter` | | 新鲜度元数据 |

#### Snapshot / Delta

**Snapshot（全量替换某 instance 范围）：**

```json
{
  "snapshot": {
    "providerInstanceId": "inst_flight_1",
    "items": [ "/* Item[] */" ]
  }
}
```

**Delta（增量）：**

```json
{
  "delta": {
    "providerInstanceId": "inst_flight_1",
    "upsert": [ "/* Item[] */" ],
    "delete": [ { "providerInstanceId": "inst_flight_1", "localId": "AA200" } ]
  }
}
```

### 3.4 Core 处理 Item 更新的步骤

1. 认证 OPP 通道
2. 校验 `type` 是否在 manifest `itemTypes` 中
3. 校验 `payload` 对应该 type 的 schema
4. 校验 `render`（若有）对 Render IR schema
5. Upsert SQLite
6. EventBus 发出 `item.changed`
7. 按需失效 CacheLayer

### 3.5 Hub（Phase 5，可选）

Hub = **同一代码库的 Core**，无 SwiftUI 客户端，额外提供：

- Scheduler / Webhook 入站
- 多设备 Item 聚合
- 加密 Secret Store
- Sync Protocol 服务端

**Hub 不得在 Core MVP（Phase 2）完成前开发。**

---

## 4. OPP：Provider 协议

OPP = **OmniBoard Provider Protocol**，LSP 风格的 **JSON-RPC 2.0**，带能力协商。

- 编码：JSON（canonical）；MessagePack 可协商（后期）
- 传输：stdio（默认）；Unix socket / TCP 可选
- 帧格式：Content-Length 头 + JSON body（与 Client Protocol 相同）

### 4.1 握手：`initialize`

**Core → Provider（request）：**

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
      "encoding": ["json"]
    },
    "instance": {
      "providerInstanceId": "inst_flight_1",
      "config": { "route": "JFK-LHR" },
      "locale": "en-US"
    }
  }
}
```

**Provider → Core（result）：**

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

然后 Core 发送 notification `initialized`。最终能力 = 双方交集。

### 4.2 能力标识

| Capability | 含义 |
| ---------- | ---- |
| `items.push` | Provider 可发 `items/changed` |
| `items.pull` | Core 可调 `items/get` / `items/query` |
| `actions.execute` | Provider 处理 `actions/execute` |
| `cache.hints` | 可附 cache 指令 |
| `encoding.msgpack` | 允许二进制帧 |
| `log` | 可发 `log` notification |
| `provider.ping` | 支持健康 ping |

未知 capability 忽略（前向兼容）。

### 4.3 方法表

**Request（Core → Provider，除非注明）：**

| 方法 | 用途 |
| ---- | ---- |
| `initialize` | 握手 |
| `shutdown` | 优雅停止 |
| `provider/ping` | 存活探测 |
| `items/get` | 按 id 拉取（需 items.pull） |
| `items/query` | 过滤查询（需 items.pull） |
| `actions/execute` | 执行动作 |
| `config/updated` | 推送配置变更 |

**Notification：**

| 方法 | 方向 | 用途 |
| ---- | ---- | ---- |
| `initialized` | Core → Provider | 握手完成 |
| `items/changed` | Provider → Core | snapshot 或 delta |
| `provider/status` | Provider → Core | ready / degraded / stopping |
| `log` | Provider → Core | 结构化日志 |
| `exit` | Provider → Core | 即将退出 |

### 4.4 `items/changed` 示例

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
              "type": "Text",
              "value": "AA100 · Boarding"
            }
          }
        }
      ],
      "delete": []
    },
    "cache": { "ttlMs": 60000, "tags": ["flights"] }
  }
}
```

### 4.5 错误码

| Code | Name | 含义 |
| ---- | ---- | ---- |
| -32700 | Parse error | JSON 无效 |
| -32600 | Invalid request | 信封错误 |
| -32601 | Method not found | 未知方法 |
| -32602 | Invalid params | Schema 失败 |
| -32603 | Internal error | Provider bug |
| -32000 | ProviderCrash | 监督进程崩溃 |
| -32001 | Timeout | 超时 |
| -32002 | AuthExpired | 需重新认证 |
| -32003 | PermissionDenied | 缺授权 |
| -32004 | InvalidRender | IR 硬拒绝 |
| -32005 | RateLimited | 限流（含 retryAfterMs） |
| -32006 | StaleData | Provider 自知数据过期 |
| -32007 | Unavailable | 临时不可用 |

---

## 5. Client Protocol：前端 ↔ Core

Renderer（SwiftUI App / Widget 等）通过 Client Protocol 与 Core 通信。

- 传输：Unix domain socket，默认路径 **`/tmp/omniboard.sock`**
- 帧格式：`Content-Length: N\r\n\r\n` + JSON body
- 语义：JSON-RPC 2.0

### 5.1 已实现（MVP）

#### `ping`

```json
// request
{ "jsonrpc": "2.0", "id": 1, "method": "ping", "params": {} }
// response
{ "jsonrpc": "2.0", "id": 1, "result": { "ok": true } }
```

#### `items/list`

```json
// request
{
  "jsonrpc": "2.0", "id": 2, "method": "items/list",
  "params": { "providerInstanceId": "inst_clock_1" }
}
// response
{ "jsonrpc": "2.0", "id": 2, "result": { "items": [ /* Item[] */ ] } }
```

#### `items/get`

```json
// request
{
  "jsonrpc": "2.0", "id": 3, "method": "items/get",
  "params": {
    "id": { "providerInstanceId": "inst_clock_1", "localId": "now" }
  }
}
// response
{ "jsonrpc": "2.0", "id": 3, "result": { "item": { /* Item */ } } }
```

### 5.2 待实现（按优先级）

| 方法 | 用途 |
| ---- | ---- |
| `items/subscribe` | 订阅 Item 变更（EventBus → 推送 notification） |
| `actions/invoke` | UI 触发 Action |
| `providers/list` | 已安装 Provider 实例列表 |
| `board/surfaces/get` | 读取用户 Board 布局 |
| `board/surfaces/put` | 保存 Board 布局 |

#### `actions/invoke`（规划）

```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "method": "actions/invoke",
  "params": {
    "invocationId": "inv_01JABC",
    "actionId": "com.example.flight.checkIn",
    "providerInstanceId": "inst_flight_1",
    "itemId": { "providerInstanceId": "inst_flight_1", "localId": "AA100" },
    "params": { "confirmation": "ABC123" },
    "idempotencyKey": "inv_01JABC"
  }
}
```

Core 校验 paramsSchema + PermissionBroker → 转发 Provider `actions/execute` → 返回 result / followUp / error。

---

## 6. Render IR：声明式 UI 契约

Provider 发出 **Render IR**（JSON 语义组件树）。SwiftUI Renderer 递归映射为原生控件。

### 6.1 设计规则

1. **禁止** 像素布局、SwiftUI 类型名、HTML、CSS
2. 只允许**语义**组件（Text、HStack、Gauge…）
3. `surfaceHints` + `SurfaceSwitch` 让同一份 IR 适配 App / Widget / Live Activity
4. 未知节点 → `fallback` 子节点 → 否则省略（**不 crash**）
5. Renderer 须支持 schema 版本 N 和 N−1

### 6.2 文档信封

```json
{
  "schemaVersion": "1.0",
  "surfaceHints": ["widgetMedium", "lockScreen"],
  "localization": { "locale": "en-US", "defaultTable": "FlightProvider" },
  "root": { "type": "VStack", "children": [] }
}
```

### 6.3 Surface Hints

| Hint | 消费者 |
| ---- | ------ |
| `lockScreen` | 锁屏小组件 |
| `widgetSmall` / `widgetMedium` / `widgetLarge` | WidgetKit |
| `liveActivity` | ActivityKit 横幅 |
| `dynamicIsland` | 灵动岛 |
| `menuBar` | macOS 菜单栏 |
| `watchComplication` | watchOS 复杂功能 |
| `canvas` | 主 App Board / 详情 |

### 6.4 组件词汇表（v1）

| Type | 作用 | 关键字段 |
| ---- | ---- | -------- |
| `Text` | 文本 | `value`, `key`, `style`（title/body/caption/mono） |
| `Symbol` | SF Symbol | `name`, `accessibilityLabel` |
| `Image` | 图片 | `uri`, `contentMode` |
| `HStack` / `VStack` | 线性布局 | `children`, `spacing`, `alignment` |
| `Grid` | 网格 | `children`, `columns` |
| `List` | 垂直列表 | `children` |
| `Gauge` | 标量仪表 | `value`, `min`, `max`, `label` |
| `Progress` | 进度 | `value?`, `label` |
| `RelativeTime` | 相对时间 | `instant`（ISO-8601） |
| `Sparkline` | 迷你折线 | `points[]` |
| `Conditional` | 条件分支 | `when`, `then`, `else` |
| `SizeClassSwitch` | 密度分支 | `compact`, `regular` |
| `SurfaceSwitch` | 按 surface 分支 | `cases{ hint: node }`, `default` |
| `ActionButton` | 触发 Action | `actionId`, `label`, `params` |
| `Fallback` | 显式降级 | `primary`, `fallback` |

每个节点可有通用字段：

```json
{
  "type": "Text",
  "value": "Boarding",
  "id": "status",
  "accessibility": { "role": "header", "label": "Flight status" },
  "fallback": { "type": "Text", "value": "Status unavailable" }
}
```

### 6.5 完整示例（航班 · Widget + 灵动岛）

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

### 6.6 校验与降级（Core + Renderer 共同遵守）

1. 根节点 schema 无效 → 硬拒绝（InvalidRender）
2. 未知可选字段 → strip 保留
3. 未知 node type → 用 `fallback`；无 fallback → 省略 + 软警告
4. 整棵树 collapse → 渲染安全占位（Widget 时间线不能 throw）

---

## 7. Action 系统

### 7.1 流程

```
UI (ActionButton tap)
  → Core: actions/invoke
  → Core: 校验 params + PermissionBroker
  → Provider: actions/execute
  → Core → UI: action.completed | action.followUp | action.failed
```

### 7.2 Manifest 声明

```json
{
  "id": "com.example.flight.checkIn",
  "titleKey": "action.checkIn",
  "paramsSchema": {
    "type": "object",
    "properties": { "confirmation": { "type": "string" } },
    "required": ["confirmation"]
  },
  "resultSchema": {
    "type": "object",
    "properties": {
      "ok": { "type": "boolean" },
      "boardingPassUri": { "type": "string", "format": "uri" }
    },
    "required": ["ok"]
  },
  "permissions": ["network.hosts"],
  "destructive": false,
  "idempotent": true
}
```

Render IR 中 `ActionButton.actionId` 引用此 id。

### 7.3 Follow-up（OAuth / 确认框）

Provider 可返回 followUp 请求 → Core 转发 UI → 用户完成 → `actions/continue` → 再次 `actions/execute`。

---

## 8. 前端：SwiftUI 客户端

### 8.1 技术栈

| 组件 | 技术 |
| ---- | ---- |
| 主 App | SwiftUI，iOS 17+ / macOS 14+，单 codebase |
| 共享库 | OmniBoardKit（Swift Package 或 Xcode target） |
| 扩展 | WidgetKit / ActivityKit / watchOS（Phase 3） |
| 构建 | Xcode 16+；Apple 端**不用 Nix** |

### 8.2 模块结构

```
clients/apple/                          # Swift Package 方案
├── Package.swift
└── Sources/
    ├── OmniBoardKit/
    │   ├── Models.swift                # Item, ItemId, JSONValue, RenderDocument
    │   ├── CoreClient.swift            # Unix socket Client Protocol
    │   ├── RenderIR.swift              # RenderNode 类型
    │   └── RenderIRView.swift          # IR → SwiftUI
    ├── OmniBoardApp/
    │   └── OmniBoardApp.swift          # @main + BoardView
    └── OmniBoardKitSmoke/
        └── main.swift                  # 无 GUI 解码冒烟

# 或 Xcode 工程方案（当前 scaffold）：
OmniBoard.xcodeproj/
OmniBoard/
├── OmniBoardApp.swift
├── Views/OmniBoardView.swift           # 占位 → 将来替换为 BoardView
└── Assets.xcassets/
```

### 8.3 Swift 模型（参考实现）

```swift
public struct ItemId: Codable, Hashable, Sendable {
    public var providerInstanceId: String
    public var localId: String
    public var canonical: String { "\(providerInstanceId):\(localId)" }
}

public struct Item: Codable, Sendable, Identifiable {
    public var id: ItemId
    public var type: String
    public var revision: UInt64
    public var updatedAt: String
    public var payload: [String: JSONValue]
    public var render: RenderDocument?
    public var actions: [String]?
    public var tags: [String]?
    public var asOf: String?
    public var staleAfter: String?
}
```

### 8.4 CoreClient（参考实现要点）

```swift
public final class CoreClient {
    public init(socketPath: String = "/tmp/omniboard.sock")

    public func ping() async throws -> Bool
    public func listItems(providerInstanceId: String) async throws -> [Item]
    public func getItem(id: ItemId) async throws -> Item?
    // 将来：subscribe, invokeAction, listProviders
}
```

- 使用 `Network.framework` 的 `NWConnection` 连 Unix socket
- Content-Length 帧编解码
- JSON-RPC request/response

### 8.5 RenderIRView 映射表

| IR type | SwiftUI |
| ------- | ------- |
| `Text` | `Text`，style → font |
| `Symbol` | `Image(systemName:)` |
| `HStack` / `VStack` | 对应 Stack + ForEach children |
| `SurfaceSwitch` | 按 `surfaceHint` 选 cases 分支 |
| `ActionButton` | `Button` → 调 `actions/invoke` |
| `RelativeTime` | `Text` + caption 样式 |
| `Fallback` | primary 失败 → fallback |
| **default** | 有 fallback 用 fallback，否则 EmptyView |

### 8.6 App 界面结构（目标 MVP）

```
OmniBoardApp (@main)
└── NavigationStack
    ├── BoardView                    ← Phase 2 核心界面
    │   ├── Core 连接状态指示
    │   └── LazyVGrid / List
    │       └── ForEach(items) { item in
    │             RenderIRView(node: item.render.root, surfaceHint: "canvas")
    │           }
    ├── ProviderSettingsView       ← Phase 2/4
    └── ItemDetailView             ← 可选
```

**当前 scaffold 状态：** 只有 `OmniBoardView` 占位页（ContentUnavailableView），尚未接 Core。

### 8.7 当前 Scaffold 文件（Xcode 工程，可直接打开）

```
OmniBoard/
  OmniBoardApp.swift          # @main → OmniBoardView()
  Views/OmniBoardView.swift   # 占位 "Your board will appear here."
  Assets.xcassets/            # AppIcon + AccentColor 槽位
OmniBoard.xcodeproj/          # iOS + macOS 共享 target
.gitignore                    # Swift/Xcode
.github/workflows/build.yml   # macOS CI
README.md                     # 打开/运行说明
```

打开方式：Xcode 16+ → 打开 `OmniBoard.xcodeproj` → 选 OmniBoard scheme → ⌘R。

---

## 9. 端到端数据流

### 9.1 Item 更新

```
用户配置 Provider
  → Core 启动进程 → OPP initialize
  → Provider 发 items/changed (delta)
  → Core 校验 → SQLite → EventBus item.changed
  → App items/list 或 subscribe → RenderIRView 渲染
  → Widget 读 CacheLayer snapshot（Phase 3）
```

### 9.2 Action 执行

```
用户点 ActionButton
  → App actions/invoke
  → Core 校验 → Provider actions/execute
  → 结果回 App；Provider 可能同时 push items/changed
```

### 9.3 离线 / Provider 崩溃

- SQLite 保留 last-good 数据
- UI 显示 stale 指示（asOf / staleAfter）
- Provider 重启期间 Board 仍可浏览
- 错误以 chip/banner 展示，不白屏

---

## 10. 仓库结构与文件清单

### 10.1 目标 Monorepo 完整树

```
OmniBoard/
├── README.md
├── ARCHITECTURE.md                 # 架构索引（长文档）
├── docs/
│   └── PRODUCT_PLAN.md             # 本文档
├── packages/
│   └── protocol/                   # JSON Schema + fixtures
│       ├── schemas/
│       ├── fixtures/
│       └── registries/
├── core/                           # Rust Core
├── hub/                            # 无头 Hub（Phase 5）
├── clients/apple/                  # Swift Package + App
├── providers/                      # 参考 Provider
│   └── clock/                      # 第一个 demo Provider
├── tools/                          # 一致性测试
├── flake.nix                       # Nix 开发环境（Rust/Python）
├── Justfile                        # just check / just run-clock
└── .github/workflows/build.yml     # macOS CI
```

### 10.2 参考 Provider：clock

最小 Provider 只需实现：

1. `initialize` → 返回 capabilities
2. 周期性 `items/changed` → 推送当前时间 Item
3. （可选）`actions/execute`

### 10.3 联调命令

```bash
# 终端 A — 后端（需 Nix + Rust）
nix develop -c just run-clock
# 启动 Core，监听 /tmp/omniboard.sock，监督 clock Provider

# 终端 B — 前端（需 macOS + Swift）
cd clients/apple
swift run OmniBoardKitSmoke    # 模型解码冒烟（无需 Xcode.app）
swift run OmniBoardApp         # GUI（需图形会话）

# 或 Xcode
open OmniBoard.xcodeproj       # scaffold 方案
```

---

## 11. 开发环境要求

| 工作 | 环境 | 命令 |
| ---- | ---- | ---- |
| Core / Provider（Rust, Python） | macOS/Linux + Nix | `nix develop -c just check` |
| Apple 客户端 | **macOS** + Xcode 16+ | 打开 xcodeproj 或 `swift run` |
| CI | GitHub Actions `macos-*` | xcodebuild |
| Cloud Agent / Linux | **无法** 编译 SwiftUI | 仅可编辑源码，不能 Run |

---

## 12. 分阶段实施计划

> 按依赖顺序，不含日历估算。

### Phase 0 — 架构与脚手架 ✅

| 任务 | 状态 |
| ---- | ---- |
| 产品/架构文档 | ✅ 本文档 |
| SwiftUI 空壳（Xcode 工程，iOS+macOS） | ✅ OmniBoard.xcodeproj |
| 合并 Rust Core + Swift Kit 到 main | ⬜ 待做 |

**退出标准：** Xcode 可 Run 空壳 App。

---

### Phase 1 — 协议包

| # | 任务 |
| - | ---- |
| 1.1 | Item / Manifest / Render IR 的 JSON Schema |
| 1.2 | OPP 消息 Schema |
| 1.3 | Golden fixtures + 一致性 runner |

**退出标准：** 所有 fixture 自动校验通过。

---

### Phase 2 — Core MVP（第一个可演示版本）⭐ 建议从这里开始写代码

| # | 任务 |
| - | ---- |
| 2.1 | Rust ItemStore (SQLite) |
| 2.2 | OPP framing + ProviderSupervisor (stdio) |
| 2.3 | Render IR 软校验 |
| 2.4 | EventBus + ActionRouter 基线 |
| 2.5 | Client Protocol Unix socket |
| 2.6 | 参考 Provider：clock |
| 2.7 | OmniBoardKit：CoreClient + RenderIRView |
| 2.8 | BoardView 替换占位 OmniBoardView |
| 2.9 | `just run-clock` 一键演示 |

**退出标准：**

- 终端 A：`just run-clock`
- 终端 B：App 看到 clock Item
- 停 Provider 后 App 仍显示 last-good
- 至少一个 Action round-trip

---

### Phase 3 — Apple 多 Surface

- WidgetKit + snapshot
- Live Activity spike
- BoardSurface 编辑器
- SurfaceSwitch 测试矩阵

**退出标准：** 同一 Render IR 驱动 App + Widget。

---

### Phase 4 — 权限、认证、打包

- Keychain secretRefs + OAuth UX
- 网络 allowlist
- Provider 包签名
- 官方 SDK（TS 或 Python）

---

### Phase 5 — Hub（可选）

- 无头 Core 部署
- Scheduler / Webhook
- Sync Protocol
- 双设备同步

**退出标准：** wipe Hub 后本地仍可用。

---

### Phase 6 — 生态

- 更多 SDK、一致性 CI 门禁、Render IR 设计指南、RFC 流程

---

## 13. 近期实施 Checklist

复制到你的 issue tracker，按顺序勾选。

### 后端（Rust）

- [ ] 引入 `core/` crate，`cargo test` 通过
- [ ] ItemStore：create / get / list_by_instance
- [ ] Client Protocol：`ping`, `items/list`, `items/get` on `/tmp/omniboard.sock`
- [ ] ProviderSupervisor：stdio 启动子进程
- [ ] OPP：`initialize` + `items/changed` 入库
- [ ] EventBus：`item.changed` 事件
- [ ] ActionRouter：`actions/invoke` → `actions/execute`
- [ ] `just run-clock` 脚本

### 前端（Swift）

- [ ] 引入 OmniBoardKit（SPM 或拖入 xcodeproj）
- [ ] CoreClient 连 `/tmp/omniboard.sock`
- [ ] BoardView：`listItems` → ForEach → RenderIRView
- [ ] Core 离线空态
- [ ] ActionButton → `actions/invoke`
- [ ] `#Preview` 用 fixture JSON

### Provider

- [ ] `providers/clock`：`initialize` + 定时 `items/changed`
- [ ] Item 含简单 Render IR（Text + RelativeTime）
- [ ] （可选）一个 demo action

### 基础设施

- [ ] `packages/protocol` fixtures
- [ ] GitHub Actions macOS build 绿
- [ ] README 联调说明

---

## 14. 非目标与风险

### 非目标（现阶段不做）

- 进程内原生插件
- Core 内嵌领域 UI 模板
- 强制云端 / Hub
- gRPC / MessagePack 默认传输
- 非 Apple 官方客户端
- 通用 IFTTT / 工作流引擎

### 风险与缓解

| 风险 | 缓解 |
| ---- | ---- |
| Render IR 表达力不足 | SurfaceSwitch + Fallback；版本化 schema |
| Provider 质量参差 | 一致性测试 + 进程隔离 + last-good UI |
| 多 Apple target 维护成本 | 共享 OmniBoardKit；IR 驱动 |
| Core/Hub 代码分叉 | Hub = 同代码库无头打包 |
| Linux/Cloud 无法编译 Swift | CI 用 macOS runner；本地开发必须 macOS |

---

*文档版本：2026-09-17 · All-in-One 自包含版*
