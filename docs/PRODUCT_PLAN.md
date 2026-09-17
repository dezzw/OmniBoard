# OmniBoard 产品说明与实施计划

> 本文档将 OmniBoard 的前后端设计整理为一份可执行的产品说明与分阶段计划。  
> 目标读者：产品负责人与实施开发者（Swift / Rust / Provider 作者）。

---

## 1. 产品定位

**OmniBoard** 是一款 **Apple 优先** 的个人信息面板（Personal Information Surface）：

- 本地 **Core** 作为可信运行时，托管 **进程外 Provider**，校验并持久化数据
- Provider 通过 **OPP**（OmniBoard Provider Protocol）推送结构化 **Item** 与声明式 **Render IR**
- **SwiftUI 渲染层**（App、Widget、Live Activity、Watch、菜单栏）只与 Core 通信，不直连 Provider
- 可选 **Hub**（无头 Core）用于聚合、调度、多设备同步——**不依赖云端也能完整运行**

### 核心原则

| 原则 | 含义 |
| ---- | ---- |
| Provider 权威 | 领域数据与 payload schema 由 Provider 拥有；Core 只做校验，不做业务语义 |
| 声明式 Render IR | Provider 描述「展示什么」，SwiftUI 决定「怎么画」 |
| 进程隔离 | Provider 不可信；Core 负责权限、重启、失败隔离 |
| 本地优先 | SQLite 为设备端真相源；Hub 可选 |
| 软失败 | 未知 Render 节点降级；Provider 崩溃后 UI 仍显示 last-good 数据 |

---

## 2. 系统架构（前后端边界）

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
│  后端 · OmniBoard Core（Rust，本地或 Hub 嵌入）                   │
│  ItemStore │ EventBus │ ActionRouter │ ProviderSupervisor        │
│  PermissionBroker │ CacheLayer │ Render IR 校验 │ SyncEngine     │
│                              │ OPP                               │
└──────────────────────────────┼───────────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Provider 进程（任意语言）                                         │
│  航班 / 日历 / 天气 / 自定义数据源 …                               │
└─────────────────────────────────────────────────────────────────┘

        （可选）Sync Protocol ◄──► Hub（无头 Core + 调度 / Webhook）
```

### 三条协议

| 协议 | 通信方 | 默认通道 | 职责 |
| ---- | ------ | -------- | ---- |
| **OPP** | Core ↔ Provider | stdio（可选 Unix socket / TCP） | 初始化、推送 Item、执行 Action |
| **Client Protocol** | Renderer ↔ Core | XPC 或本地 Unix socket | 读 Item、订阅事件、触发 Action |
| **Sync Protocol** | Core ↔ Hub | TLS / WebSocket | Item 与用户状态同步（后期） |

**硬性规则：**

1. Renderer **不得** 直接调用 Provider
2. Provider **不得** 嵌入 SwiftUI / HTML / 像素布局
3. Core **不得** 解释 payload 内的领域字段（仅 JSON Schema 校验）
4. 无 Hub、无网络时，Core 仍须完整可用

---

## 3. 后端设计（Core + Hub）

### 3.1 技术栈

| 组件 | 技术 | 说明 |
| ---- | ---- | ---- |
| Core / Hub 运行时 | **Rust** | 同一套可嵌入代码；Hub = 无 UI 的 Core |
| 持久化 | **SQLite** | Item、实例元数据、BoardSurface 布局 |
| Provider 通信 | **JSON-RPC 2.0** + Content-Length 帧 | 与 LSP 类似的分帧 |
| 开发环境 | Nix flake + `just` | Rust / Python Provider；Apple 端不用 Nix |

### 3.2 Core 子系统职责

| 子系统 | 职责 |
| ------ | ---- |
| **ItemStore** | Item / RenderDocument 持久化；revision 单调递增 |
| **ProviderSupervisor** | 安装、配置、启停、健康检查、崩溃重启 |
| **Render IR Adapter** | 校验 IR schema；未知节点 strip / degrade |
| **PermissionBroker** | Manifest 声明能力 vs 用户授权 |
| **ActionRouter** | 校验参数 → 权限 → 转发 `actions/execute` → 返回结果 |
| **EventBus** | 进程内事件； fan-out 到 Client Protocol 订阅者 |
| **CacheLayer** | Item / Render 缓存；尊重 Provider cache hints |
| **SyncEngine** | （后期）与 Hub 同步 Item 与用户状态 |
| **Secret Broker** | Keychain / Hub 加密存储；向 Provider 注入临时凭证 |
| **BoardSurface Store** | 用户布局：哪些 Item 出现在哪些 surface slot |

### 3.3 Core **不做**的事

- 不调用第三方 API（GitHub、航司、天气等）—— 属于 Provider
- 不渲染 UI
- v1 不支持进程内原生插件
- 不以明文持久化 Provider 密钥

### 3.4 数据模型（后端视角）

#### ProviderManifest

Provider 包的静态契约：id、版本、OPP 版本、capabilities、permissions、configSchema、itemTypes、actions。

#### ProviderInstance

某 Manifest 的一个已配置实例：`inst_…`、用户 config、secretRefs、生命周期 state。

#### Item

```json
{
  "id": { "providerInstanceId": "inst_flight_1", "localId": "AA100" },
  "type": "com.example.flight.status",
  "revision": 42,
  "updatedAt": "2026-08-04T20:00:00Z",
  "payload": { "flightNumber": "AA100", "status": "boarding", "gate": "B12" },
  "render": {
    "schemaVersion": "1.0",
    "root": { "type": "Text", "value": "AA100 · Gate B12" }
  },
  "actions": ["com.example.flight.checkIn"],
  "tags": ["travel", "today"],
  "ttl": "PT6H",
  "priority": 10
}
```

- **ItemId** 规范字符串：`inst_flight_1:AA100`
- 变更通过 **snapshot**（全量替换）或 **delta**（upsert + delete）推送

### 3.5 OPP 关键方法

**Core → Provider（Request）**

| 方法 | 用途 |
| ---- | ---- |
| `initialize` | 能力协商握手 |
| `shutdown` | 优雅停止 |
| `provider/ping` | 存活探测 |
| `items/get` / `items/query` | 拉取（需 `items.pull` 能力） |
| `actions/execute` | 执行动作 |
| `config/updated` | 推送配置变更 |

**Provider → Core（Notification）**

| 方法 | 用途 |
| ---- | ---- |
| `items/changed` | 推送 snapshot 或 delta |
| `provider/status` | ready / degraded / stopping |
| `log` | 结构化日志 |

**Capability 示例：** `items.push`、`items.pull`、`actions.execute`、`cache.hints`

### 3.6 Client Protocol（后端暴露给前端）

当前 MVP 已实现（架构分支 `core/src/client.rs`）：

| 方法 | 参数 | 返回 |
| ---- | ---- | ---- |
| `ping` | — | `{ ok: true }` |
| `items/list` | `providerInstanceId` | `{ items: Item[] }` |
| `items/get` | `id: ItemId` | `{ item: Item \| null }` |

**待实现（按优先级）：**

| 方法 | 用途 |
| ---- | ---- |
| `items/subscribe` | 订阅 Item 变更（EventBus → Client） |
| `actions/invoke` | UI 触发 Action |
| `providers/list` | 已安装 Provider 实例 |
| `board/surfaces/get` / `put` | 读取 / 保存用户 Board 布局 |

**传输：** Unix domain socket，默认 `/tmp/omniboard.sock`；帧格式 `Content-Length` + JSON body。

### 3.7 Hub（可选，Phase 5）

- 与 Core **同代码库**，打包为无头部署
- 额外能力：Scheduler、Webhook 入站、多设备聚合、加密 Secret Store
- **不得** 在 Core MVP 完成之前启动 Hub 开发

---

## 4. 前端设计（Apple Renderers）

### 4.1 技术栈

| 组件 | 技术 | 说明 |
| ---- | ---- | ---- |
| 主 App | **SwiftUI** | iOS 17+ / macOS 14+，单 codebase 多平台 |
| 共享库 | **OmniBoardKit**（Swift Package） | 模型、CoreClient、RenderIRView |
| 扩展 | WidgetKit / ActivityKit / watchOS | 消费同一份 Render IR + snapshot |
| 构建 | Xcode 16+ 或 `swift run` | Apple 端在 macOS 宿主开发，不用 Nix |

### 4.2 模块划分

```
clients/apple/                    # 或根目录 OmniBoard.xcodeproj（当前 scaffold）
├── Sources/OmniBoardKit/
│   ├── Models.swift              # Item, ItemId, ProviderInstance …
│   ├── CoreClient.swift          # Client Protocol 客户端
│   ├── RenderIR.swift            # Render IR 类型定义
│   └── RenderIRView.swift        # IR → SwiftUI 映射
├── Sources/OmniBoardApp/
│   └── OmniBoardApp.swift        # @main，Board 主界面
└── Sources/OmniBoardKitSmoke/    # 无 GUI 的模型/解码冒烟测试
```

### 4.3 前端职责

| 层级 | 职责 |
| ---- | ---- |
| **OmniBoardApp** | 导航、Board 布局 shell、Provider 管理 UI、Action follow-up 弹窗 |
| **OmniBoardKit** | 协议客户端、模型解码、Render IR → SwiftUI |
| **RenderIRView** | 递归渲染语义节点；未知 type 走 fallback |
| **Surface 适配** | 通过 `surfaceHint`（widgetMedium、lockScreen、canvas …）选择 IR 分支 |

### 4.4 Render IR（前端消费契约）

Provider 发出的 JSON 树，**不含** SwiftUI 类型或像素布局。

**文档信封：**

```json
{
  "schemaVersion": "1.0",
  "surfaceHints": ["widgetMedium", "canvas"],
  "root": { "type": "VStack", "children": [] }
}
```

**已规划节点类型（MVP 优先实现）：**

| 节点 | SwiftUI 映射 |
| ---- | ------------ |
| `Text` | `Text`，支持 style: title / caption / mono |
| `Symbol` | `Image(systemName:)` |
| `HStack` / `VStack` | 对应 Stack |
| `ActionButton` | `Button` → 调用 `actions/invoke` |
| `RelativeTime` | 相对时间文本 |
| `SurfaceSwitch` | 按 surfaceHint 选分支 |
| `Fallback` | primary 失败时显示 fallback |

**降级策略：** 未知 `type` → 渲染 `fallback` 子节点 → 否则 `EmptyView`（不 crash）。

### 4.5 主界面信息架构（App shell）

当前 scaffold 仅有占位页；完整 MVP 建议结构：

```
OmniBoardApp
└── NavigationStack
    ├── BoardView（主 Board，网格/列表展示 Item 卡片）
    │   └── RenderIRView(item.render.root, surfaceHint: "canvas")
    ├── ProviderSettingsView（已安装 Provider、启停、配置）
    └── ItemDetailView（可选，大卡片 + Action 按钮）
```

**数据流（前端）：**

1. App 启动 → `CoreClient.ping()` 检测 Core 是否在线
2. `items/list` 拉取各 ProviderInstance 的 Item
3. （后期）订阅 `item.changed` 事件，增量刷新 UI
4. 用户点 ActionButton → `actions/invoke` → 展示结果或 follow-up（OAuth / 确认框）

### 4.6 多 Surface 扩展（Phase 3）

同一 Render IR + `surfaceHints` 驱动：

| Surface | 技术 | 数据获取 |
| ------- | ---- | -------- |
| 主 App | SwiftUI | Client Protocol 实时 |
| Widget | WidgetKit | Core 提供的 snapshot 缓存 |
| Live Activity | ActivityKit | 高优先级 Item + 推送更新 |
| Menu Bar | SwiftUI MenuBarExtra | 精简 IR + `menuBar` hint |
| Watch | watchOS complication | 最小节点子集 |

---

## 5. 端到端数据流

### 5.1 Item 更新（Happy Path）

```
1. 用户安装并配置 Provider
2. Core 启动受监督进程 → OPP initialize 能力协商
3. Provider 发送 items/changed (delta)
4. Core：校验 type + payload schema + Render IR → 写入 SQLite
5. EventBus 发出 item.changed
6. App（订阅或轮询）读取 Item → RenderIRView 渲染
7. Widget 从 CacheLayer snapshot 读取同一 IR
```

### 5.2 Action 执行

```
1. 用户点击 Render IR 中的 ActionButton
2. App → Core: actions/invoke(actionId, itemId, params)
3. Core：校验 paramsSchema + PermissionBroker
4. Core → Provider: actions/execute
5. Provider 返回 result 或 followUp（如需 OAuth）
6. Core → App: action.completed / action.followUp / action.failed
7. 若 Provider 同时推送 items/changed，Board 自动刷新
```

### 5.3 离线 / Provider 崩溃

- Core 保留 **last-good** SQLite 数据
- UI 显示 stale 指示（`asOf` / `staleAfter` 元数据）
- Provider 重启期间 Board 仍可浏览缓存 Item
- 错误以 chip / banner 展示，不白屏

---

## 6. 仓库布局（目标 monorepo）

```
OmniBoard/
├── README.md
├── ARCHITECTURE.md                 # 架构索引（架构分支已有）
├── docs/
│   ├── architecture/               # 01–21 规范文档
│   └── PRODUCT_PLAN.md             # 本文档
├── packages/protocol/              # JSON Schema + fixtures + registries
├── core/                           # Rust Core
├── hub/                            # 无头 Hub 部署（后期）
├── clients/apple/                  # Swift Package + App
│   或 OmniBoard.xcodeproj/         # 当前 PR 的 Xcode scaffold
├── providers/                      # 参考 Provider（clock 等）
├── tools/                          # 一致性测试、lint
├── flake.nix / Justfile            # Rust/Python 开发环境
└── .github/workflows/              # macOS 构建 CI
```

**环境分工：**

| 工作 | 环境 |
| ---- | ---- |
| Core / Provider（Rust, Python） | `nix develop` + `just check` |
| Apple 客户端 | macOS + Xcode 16 / `swift run` |
| CI | GitHub Actions `macos-*` runner（Linux 无法编译 SwiftUI） |

---

## 7. 分阶段实施计划

各阶段按 **依赖顺序** 排列，不含日历估算。每阶段列出可验收的交付物。

### Phase 0 — 架构与脚手架 ✅ 部分完成

| 任务 | 状态 | 说明 |
| ---- | ---- | ---- |
| 规范架构文档 01–21 | ✅ 架构分支 | `cursor/omniboard-architecture-0a30` |
| SwiftUI 空壳 App | ✅ 当前 PR | `OmniBoard.xcodeproj` + 占位 OmniBoardView |
| 合并架构文档到 main | ⬜ 待做 | 将 docs/ 与 ARCHITECTURE.md 合入 |
| 统一客户端路径 | ⬜ 待做 | 决定用 `clients/apple/` SPM 还是根目录 xcodeproj |

**退出标准：** 文档齐全；可在 Xcode 打开并 Run 空壳 App。

---

### Phase 1 — 协议包（Protocol Package）

**目标：** 所有消息有 JSON Schema；fixtures 可自动校验。

| # | 任务 | 产出 |
| - | ---- | ---- |
| 1.1 | Item / ItemId / Manifest JSON Schema | `packages/protocol/schemas/` |
| 1.2 | OPP 消息 Schema（initialize, items/changed, actions/execute） | 同上 |
| 1.3 | Render IR Schema + 节点类型注册表 | `registries/render-node-types.json` |
| 1.4 | Golden fixtures | `packages/protocol/fixtures/` |
| 1.5 | 一致性 runner 骨架 | `tools/conformance/` |

**退出标准：** `just protocol-check`（或等价命令）全部 fixture 通过；文档示例与 schema 一致。

---

### Phase 2 — Core MVP（本地）

**目标：** 单机可演示「Provider 推 Item → App 展示 → Action 往返」。

| # | 任务 | 产出 |
| - | ---- | ---- |
| 2.1 | ItemStore（SQLite CRUD + list/get） | `core/src/store.rs` |
| 2.2 | OPP framing + ProviderSupervisor（stdio） | `core/src/opp.rs`, `supervisor.rs` |
| 2.3 | Render IR 软校验 | `core/src/render.rs` |
| 2.4 | EventBus + ActionRouter 基线 | `core/src/event.rs`, action 模块 |
| 2.5 | Client Protocol Unix socket | `core/src/client.rs` |
| 2.6 | 参考 Provider：clock 或 static demo | `providers/clock/` |
| 2.7 | OmniBoardKit：CoreClient + RenderIRView | `clients/apple/` |
| 2.8 | App BoardView 展示 Item 列表 | 替换占位 OmniBoardView |
| 2.9 | `just run-clock` 一键演示 | 根目录 Justfile |

**退出标准：**

- 终端 A：`just run-clock` 启动 Core + Provider
- 终端 B：`swift run OmniBoardApp` 看到 Provider Item
- 停止 Provider 后 App 仍显示 last-good 数据
- 至少一个 Action round-trip 成功

---

### Phase 3 — Apple 多 Surface

**目标：** 同一份 Render IR 驱动 ≥2 种 surface。

| # | 任务 | 产出 |
| - | ---- | ---- |
| 3.1 | Core snapshot API / CacheLayer 适配 Widget | Client + cache |
| 3.2 | WidgetKit extension | `clients/apple/Widget/` |
| 3.3 | Live Activity spike（可选 Item 类型） | ActivityKit target |
| 3.4 | BoardSurface 编辑器基础版 | 拖拽/选择 Item 到 slot |
| 3.5 | SurfaceSwitch + hint 测试矩阵 | 单元 / 快照测试 |

**退出标准：** Widget 与 App 显示同一 Item；未知 IR 节点降级可测。

---

### Phase 4 — 权限、认证、打包

| # | 任务 | 产出 |
| - | ---- | ---- |
| 4.1 | Keychain secretRefs + OAuth UX | PermissionBroker 完整 |
| 4.2 | 网络 allowlist  enforcement | 平台沙箱集成 |
| 4.3 | Provider 包签名格式 | 安装/卸载流程 |
| 4.4 | 官方 SDK（TypeScript 或 Python） | `packages/sdks/` |

**退出标准：** 第三方风格 Provider 可安装；token 过期时 UI 优雅降级。

---

### Phase 5 — Hub（可选）

| # | 任务 | 产出 |
| - | ---- | ---- |
| 5.1 | 无头 Core 部署 | `hub/` |
| 5.2 | Scheduler + Webhook | Hub 服务 |
| 5.3 | Sync Protocol（Item + 用户状态 CRDT） | 双设备同步 |
| 5.4 | Hub 加密 Secret Store | 服务端密钥 |

**退出标准：** 两设备同步用户布局； wipe Hub 后本地模式仍可用。

---

### Phase 6 — 生态

- 更多 SDK（Go、Rust）
- Provider 一致性 CI 门禁
- Render IR 密度设计指南
- RFC 流程用于协议变更

---

## 8. 近期实施清单（建议从 Phase 2 开始）

若你 **现在** 要开始写代码，推荐顺序：

### 后端（Rust）

- [ ] 克隆/合并架构分支的 `core/` 与 `flake.nix`
- [ ] 本地跑通 `nix develop -c just check`
- [ ] 确认 `just run-clock` 监听 `/tmp/omniboard.sock`
- [ ] 为 Client Protocol 增加 `items/subscribe` 通知
- [ ] 实现 `actions/invoke` 端到端

### 前端（Swift）

- [ ] 将 OmniBoardKit 迁入当前 Xcode 工程（或改用 `clients/apple/Package.swift`）
- [ ] 实现 `BoardView`：连接 Core → `items/list` → `ForEach` + `RenderIRView`
- [ ] Core 离线时显示友好空态（当前 placeholder 可保留为 fallback）
- [ ] ActionButton 接 `actions/invoke`（Phase 2 末期）

### Provider

- [ ] 使用 `providers/clock` 作为第一个集成测试 Provider
- [ ] 新 Provider 只实现：`initialize` + `items/changed` + 可选 `actions/execute`

### 联调命令（目标体验）

```bash
# 终端 A — 后端
nix develop -c just run-clock

# 终端 B — 前端
cd clients/apple   # 或打开 OmniBoard.xcodeproj
swift run OmniBoardKitSmoke   # 冒烟
swift run OmniBoardApp        # GUI
```

---

## 9. 当前仓库状态对照

| 内容 | 位置 | 分支 |
| ---- | ---- | ---- |
| SwiftUI 空壳（Xcode 工程） | 根目录 `OmniBoard/` | `cursor/swiftui-app-scaffold-31b8` → PR #1 |
| 完整架构文档 + Rust Core + Swift Kit | 全 repo | `cursor/omniboard-architecture-0a30` |
| 本文档 | `docs/PRODUCT_PLAN.md` | 随 scaffold PR 提交 |

**建议合并策略：**

1. 先合 PR #1（Xcode 空壳 + 本文档）
2. 再开 PR 将架构分支的 `core/`、`docs/architecture/`、`packages/protocol/`、`clients/apple/` 合入
3. 统一 App 入口：要么 SPM `OmniBoardApp` 包一层 Xcode wrapper，要么把 Kit 源码拖入 xcodeproj

---

## 10. 非目标（现阶段不做）

- 进程内原生插件
- Core 内嵌领域模板（「航班卡片」写死在 Core）
- 强制云端 / Hub 才能用
- gRPC / MessagePack 默认传输（后期可选）
- 非 Apple 官方客户端
- 通用 IFTTT / 工作流引擎

---

## 11. 风险与权衡（摘要）

| 风险 | 缓解 |
| ---- | ---- |
| Render IR 表达力不足 | SurfaceSwitch + fallback；版本化 schema |
| Provider 质量参差 | 一致性测试 + 进程隔离 + last-good UI |
| Apple 多 target 维护成本 | 共享 OmniBoardKit；IR 驱动多 surface |
| Core 与 Hub 代码分叉 | Hub = 同一代码库无头打包 |

详细见架构文档 [21-risks-and-tradeoffs.md](architecture/21-risks-and-tradeoffs.md)（合并架构分支后可用）。

---

## 12. 参考文档索引

合并架构分支后，规范细节以以下文档为准：

| 文档 | 主题 |
| ---- | ---- |
| [01-system-overview.md](architecture/01-system-overview.md) | 系统总览 |
| [02-core-responsibilities.md](architecture/02-core-responsibilities.md) | Core 职责边界 |
| [04-data-model.md](architecture/04-data-model.md) | Item / Manifest 模型 |
| [05-rendering-schema.md](architecture/05-rendering-schema.md) | Render IR |
| [07-action-system.md](architecture/07-action-system.md) | Action 流程 |
| [08-plugin-protocol.md](architecture/08-plugin-protocol.md) | OPP 完整方法表 |
| [20-roadmap.md](architecture/20-roadmap.md) | 官方路线图 |

---

*文档版本：2026-09-17 · 与 OmniBoard 架构分支及 SwiftUI scaffold PR 对齐*
