import SwiftUI

struct WeatherStubCard: View {
    let temperature: String
    let location: String
    let status: String

    var body: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sun.max")
                    .font(.title2)
                    .foregroundStyle(.primary)

                Text(temperature)
                    .font(.system(size: 34, weight: .bold))

                Text(location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                StatusPill(title: status)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
    }
}

#Preview {
    WeatherStubCard(temperature: "22°", location: "Toronto", status: "Fresh")
}
