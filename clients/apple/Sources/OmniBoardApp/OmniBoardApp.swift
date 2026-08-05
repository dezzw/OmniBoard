import SwiftUI
import OmniBoardKit

@main
struct OmniBoardApp: App {
    @StateObject private var model = BoardModel()

    var body: some Scene {
        WindowGroup("OmniBoard") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 420, minHeight: 320)
        }
    }
}

@MainActor
final class BoardModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var status: String = "Disconnected"
    @Published var socketPath: String = "/tmp/omniboard.sock"
    @Published var instanceId: String = "inst_clock_1"

    private var client: CoreClient { CoreClient(socketPath: socketPath) }

    func refresh() async {
        do {
            let ok = try await client.ping()
            guard ok else {
                status = "Ping failed"
                return
            }
            items = try await client.listItems(providerInstanceId: instanceId)
            status = "Connected · \(items.count) item(s)"
        } catch {
            status = "Error: \(error.localizedDescription)"
            items = demoItem()
        }
    }

    /// Offline scaffold preview when Core is not running.
    private func demoItem() -> [Item] {
        let json = """
        {
          "schemaVersion": "1.0",
          "surfaceHints": ["canvas"],
          "root": {
            "type": "VStack",
            "children": [
              { "type": "Text", "value": "OmniBoard", "style": "title" },
              { "type": "Text", "value": "Start Core to see live provider items.", "style": "caption" },
              {
                "type": "HStack",
                "children": [
                  { "type": "Symbol", "name": "clock", "accessibilityLabel": "Clock" },
                  { "type": "Text", "value": "Demo", "style": "mono" }
                ]
              }
            ]
          }
        }
        """
        let render = try? JSONDecoder().decode(RenderDocument.self, from: Data(json.utf8))
        return [
            Item(
                id: ItemId(providerInstanceId: instanceId, localId: "demo"),
                type: "com.omniboard.demo",
                revision: 1,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                payload: [:],
                render: render,
                tags: ["demo"]
            )
        ]
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: BoardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("OmniBoard")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)

            Form {
                TextField("Socket", text: $model.socketPath)
                TextField("Instance", text: $model.instanceId)
            }
            .frame(maxHeight: 80)

            Divider()

            if model.items.isEmpty {
                ContentUnavailableView(
                    "No items",
                    systemImage: "tray",
                    description: Text("Run Core with the clock provider, then Refresh.")
                )
            } else {
                List(model.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.type)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        ItemRenderView(item: item, surfaceHint: "canvas")
                        Text("rev \(item.revision)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .task { await model.refresh() }
    }
}
