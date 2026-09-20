import SwiftUI

struct MetricWidgetView: View {
    let widget: BoardWidgetItem

    var body: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(widget.title)
                    .font(.headline.weight(.semibold))

                Text(widget.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(widget.value)
                    .font(.system(size: 34, weight: .bold))

                if let status = widget.status {
                    StatusPill(title: status)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
    }
}
