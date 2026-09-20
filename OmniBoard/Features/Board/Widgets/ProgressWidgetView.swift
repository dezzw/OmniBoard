import SwiftUI

struct ProgressWidgetView: View {
    let widget: BoardWidgetItem

    var body: some View {
        BoardCard {
            switch widget.presentation {
            case .circular:
                circularBody
            case .bar:
                barBody
            case .none:
                EmptyView()
            }
        }
    }

    private var circularBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(widget.title)
                .font(.headline.weight(.semibold))

            Text(widget.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: widget.progress ?? 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(widget.value)
                    .font(.system(size: 28, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
    }

    private var barBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(widget.title)
                        .font(.headline.weight(.semibold))

                    Text(widget.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Text(widget.value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * (widget.progress ?? 0), height: 2)
                }
            }
            .frame(height: 2)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    }
}
