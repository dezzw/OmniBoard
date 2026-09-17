import SwiftUI

struct OmniBoardView: View {
    var body: some View {
        NavigationStack {
            boardPlaceholder
                .navigationTitle("OmniBoard")
        }
    }

    private var boardPlaceholder: some View {
        ContentUnavailableView {
            Label("OmniBoard", systemImage: "square.grid.2x2")
        } description: {
            Text("Your board will appear here.")
        } actions: {
            Text("Extend this screen to add tiles, widgets, and providers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OmniBoardView()
}
