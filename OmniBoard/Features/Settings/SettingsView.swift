import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("GENERAL") {
                    settingsRow(title: "Appearance", value: "System")
                    settingsRow(title: "Accent", value: "System Blue")
                }

                Section("ON THIS IPHONE") {
                    settingsRow(title: "Data", value: "This iPhone")
                    settingsRow(title: "Version", value: "0.1")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
