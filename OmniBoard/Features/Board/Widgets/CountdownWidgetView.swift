import SwiftUI

struct CountdownWidgetView: View {
    let widget: BoardWidgetItem

    var body: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(widget.title)
                    .font(.headline.weight(.semibold))

                Text(widget.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(widget.value)
                    .font(.system(size: 48, weight: .bold))
                    .padding(.vertical, 4)

                if let status = widget.status {
                    StatusPill(title: status)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
    }
}
