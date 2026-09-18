import SwiftUI

struct CopyProgressCard: View {
    let label: String
    let progress: Double
    let progressText: String
    let caption: String

    var displayedTexts: [String] {
        [label, progressText, caption]
    }

    var body: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(label)
                        .font(.body.weight(.semibold))

                    Spacer()

                    Text(progressText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * progress, height: 2)
                    }
                }
                .frame(height: 2)

                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    CopyProgressCard(
        label: "Copy",
        progress: 0.62,
        progressText: "62%",
        caption: "On this iPhone"
    )
}
