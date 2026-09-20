import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BoardView()
                .tabItem {
                    Label("Board", systemImage: "square.grid.2x2.fill")
                }

            ServiceView()
                .tabItem {
                    Label("Service", systemImage: "waveform.path.ecg")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}
