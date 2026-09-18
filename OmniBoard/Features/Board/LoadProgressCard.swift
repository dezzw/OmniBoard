import SwiftUI

struct LoadProgressCard: View {
    let progress: Double
    let value: String
    let label: String

    var body: some View {
        BoardCard {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    LoadProgressCard(progress: 0.72, value: "72", label: "Load")
}
