import SwiftUI

/// Maps Render IR nodes to SwiftUI. Unknown types use `fallback` or omit.
public struct RenderIRView: View {
    public var node: RenderNode
    public var surfaceHint: String?

    public init(node: RenderNode, surfaceHint: String? = nil) {
        self.node = node
        self.surfaceHint = surfaceHint
    }

    public var body: some View {
        content(for: node)
    }

    @ViewBuilder
    private func content(for node: RenderNode) -> some View {
        switch node.type {
        case "Text":
            textView(node)
        case "Symbol":
            Image(systemName: node.name ?? "questionmark.circle")
                .accessibilityLabel(node.accessibilityLabel ?? node.name ?? "symbol")
        case "HStack":
            HStack(alignment: .center, spacing: 8) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    RenderIRView(node: child, surfaceHint: surfaceHint)
                }
            }
        case "VStack":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    RenderIRView(node: child, surfaceHint: surfaceHint)
                }
            }
        case "SurfaceSwitch":
            if let hint = surfaceHint, let matched = node.cases?[hint] {
                RenderIRView(node: matched, surfaceHint: surfaceHint)
            } else if let fallback = node.defaultNode {
                RenderIRView(node: fallback, surfaceHint: surfaceHint)
            } else if let first = node.cases?.values.first {
                RenderIRView(node: first, surfaceHint: surfaceHint)
            } else {
                EmptyView()
            }
        case "ActionButton":
            Button(node.label?.display ?? node.actionId ?? "Action") {}
        case "RelativeTime":
            Text(node.instant ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "Fallback":
            if let primary = node.primary {
                RenderIRView(node: primary, surfaceHint: surfaceHint)
            } else if let fallback = node.fallback {
                RenderIRView(node: fallback, surfaceHint: surfaceHint)
            } else {
                EmptyView()
            }
        default:
            if let fallback = node.fallback {
                RenderIRView(node: fallback, surfaceHint: surfaceHint)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func textView(_ node: RenderNode) -> some View {
        let value = node.value ?? node.key ?? ""
        switch node.style {
        case "title":
            Text(value).font(.title2.weight(.semibold))
        case "caption":
            Text(value).font(.caption).foregroundStyle(.secondary)
        case "mono":
            Text(value).font(.body.monospacedDigit())
        default:
            Text(value).font(.body)
        }
    }
}

public struct ItemRenderView: View {
    public var item: Item
    public var surfaceHint: String?

    public init(item: Item, surfaceHint: String? = "canvas") {
        self.item = item
        self.surfaceHint = surfaceHint
    }

    public var body: some View {
        if let render = item.render {
            RenderIRView(node: render.root, surfaceHint: surfaceHint)
        } else {
            Text(item.type)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
