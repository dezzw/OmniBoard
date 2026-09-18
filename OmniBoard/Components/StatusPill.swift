import SwiftUI

struct StatusPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.green)
            .accessibilityLabel(title)
    }
}

#Preview {
    StatusPill(title: "Fresh")
}
