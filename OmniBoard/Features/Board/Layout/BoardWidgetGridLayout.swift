import SwiftUI

struct BoardWidgetGridLayout: View {
    let widgets: [BoardWidgetItem]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(row) { widget in
                        BoardWidgetView(widget: widget)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var rows: [[BoardWidgetItem]] {
        var result: [[BoardWidgetItem]] = []
        var currentRow: [BoardWidgetItem] = []

        for widget in widgets {
            switch widget.size {
            case .small:
                currentRow.append(widget)
                if currentRow.count == 2 {
                    result.append(currentRow)
                    currentRow = []
                }
            case .medium, .large:
                if !currentRow.isEmpty {
                    result.append(currentRow)
                    currentRow = []
                }
                result.append([widget])
            }
        }

        if !currentRow.isEmpty {
            result.append(currentRow)
        }

        return result
    }
}
