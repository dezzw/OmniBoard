import SwiftUI

struct ServiceView: View {
    var displayedTexts: [String] {
        [
            "Core",
            "Storing the board on this iPhone",
            "Running",
            "Weather",
            "Local provider · serving 22°",
            "Fresh",
            "Weather source",
            "Asked for the current temperature. Shown on the Board, the Live Activity, and the island.",
            "Kept on this iPhone",
            "Not uploaded",
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section("ON THIS IPHONE") {
                    serviceStatusRow(
                        title: "Core",
                        subtitle: "Storing the board on this iPhone",
                        status: "Running"
                    )

                    serviceStatusRow(
                        title: "Weather",
                        subtitle: "Local provider · serving 22°",
                        status: "Fresh"
                    )
                }

                Section("REQUESTS") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weather source")
                        Text("Asked for the current temperature. Shown on the Board, the Live Activity, and the island.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text("Kept on this iPhone")
                        Spacer()
                        Text("Not uploaded")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Service")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func serviceStatusRow(title: String, subtitle: String, status: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            StatusPill(title: status)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ServiceView()
}
