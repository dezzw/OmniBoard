import SwiftUI

struct BoardView: View {
    private let widgets = BoardSampleData.widgets

    var displayedTexts: [String] {
        widgets.flatMap(\.displayedTexts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                BoardWidgetGridLayout(widgets: widgets)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Board")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    BoardView()
}
