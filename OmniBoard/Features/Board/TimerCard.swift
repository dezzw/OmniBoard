import SwiftUI

struct TimerCard: View {
    let opensInLabel: String
    let time: String
    let expiryCaption: String

    var body: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(opensInLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(time)
                    .font(.system(size: 48, weight: .bold))

                Text(expiryCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    TimerCard(
        opensInLabel: "Opens in",
        time: "12:40",
        expiryCaption: "Expires in 12m 40s · On this iPhone"
    )
}
