# RFC 0000：模板

> 复制本文件并重命名为 `NNNN-简短标题.md`，其中 NNNN 为四位递增编号。

## 状态

草案 | 审阅中 | 已接受 | 已废弃 | 已取代

## 摘要

用一到两段话说明本 RFC 要改什么、为什么重要。

## 动机

- 当前问题或缺口是什么？
- 哪些用户场景或系统约束驱动这次变更？

## 提案

描述具体方案：行为变化、参与方（Core、Provider、Client）、以及边界条件。

## schema diff

列出 `packages/protocol/schemas/` 下新增、修改或删除的 schema 文件，并说明字段级变化。

## 兼容性

- **OPP**：遵循 MAJOR.MINOR 语义；不兼容变更必须递增 MAJOR。
- **Item / Presentation**：渲染器实现 `Item.schemaVersion` N 与 N-1；Core 在 Phase 0 仅接受 `{1}`（省略字段视为 1）。
- 说明对现有 fixtures 与 golden 测试的影响。

## fixtures

列出 `packages/protocol/fixtures/` 中需要新增或更新的 valid/invalid 样例，并说明每条 invalid 触发的规则。

## 备选

简述考虑过但未采纳的方案及原因。

## 未决

列出仍需产品或架构决策的开放问题。
