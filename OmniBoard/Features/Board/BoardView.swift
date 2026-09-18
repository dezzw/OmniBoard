import SwiftUI

struct BoardView: View {
    private let data = BoardSampleData.preview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        WeatherStubCard(
                            temperature: data.temperature,
                            location: data.location,
                            status: data.weatherStatus
                        )

                        LoadProgressCard(
                            progress: data.loadProgress,
                            value: data.loadValue,
                            label: data.loadLabel
                        )
                    }

                    TimerCard(
                        opensInLabel: data.opensInLabel,
                        time: data.timerDisplay,
                        expiryCaption: data.timerExpiryCaption
                    )

                    CopyProgressCard(
                        label: data.copyLabel,
                        progress: data.copyProgress,
                        progressText: data.copyProgressText,
                        caption: data.copyCaption
                    )
                }
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
