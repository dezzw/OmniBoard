import Foundation
import OmniBoardKit

@main
struct OmniBoardKitSmoke {
    static func main() throws {
        let renderJSON = """
        {
          "schemaVersion": "1.0",
          "surfaceHints": ["widgetMedium"],
          "root": {
            "type": "Text",
            "value": "AA100",
            "style": "title"
          }
        }
        """.data(using: .utf8)!
        let doc = try JSONDecoder().decode(RenderDocument.self, from: renderJSON)
        precondition(doc.schemaVersion == "1.0")
        precondition(doc.root.type == "Text")
        precondition(doc.root.value == "AA100")

        let itemJSON = """
        {
          "id": { "providerInstanceId": "inst_clock_1", "localId": "now" },
          "type": "com.omniboard.clock.now",
          "revision": 3,
          "updatedAt": "2026-08-04T20:00:00Z",
          "payload": { "unix": 1 },
          "render": {
            "schemaVersion": "1.0",
            "root": { "type": "Text", "value": "12:00:00", "style": "mono" }
          },
          "tags": ["clock"]
        }
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(Item.self, from: itemJSON)
        precondition(item.id.canonical == "inst_clock_1:now")
        precondition(item.revision == 3)
        precondition(item.render?.root.style == "mono")

        print("OmniBoardKitSmoke: ok")
    }
}
