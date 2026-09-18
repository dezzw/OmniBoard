import SwiftUI

struct StatusPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.green)
    }
}

#Preview {
    StatusPill(title: "Fresh")
}
