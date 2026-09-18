import SwiftUI

struct BoardView: View {
    private let data = BoardSampleData.preview

    var displayedTexts: [String] {
        weatherCard.displayedTexts
            + loadCard.displayedTexts
            + timerCard.displayedTexts
            + copyCard.displayedTexts
    }

    private var weatherCard: WeatherStubCard {
        WeatherStubCard(
            temperature: data.temperature,
            location: data.location,
            status: data.weatherStatus
        )
    }

    private var loadCard: LoadProgressCard {
        LoadProgressCard(
            progress: data.loadProgress,
            value: data.loadValue,
            label: data.loadLabel
        )
    }

    private var timerCard: TimerCard {
        TimerCard(
            opensInLabel: data.opensInLabel,
            time: data.timerDisplay,
            expiryCaption: data.timerExpiryCaption
        )
    }

    private var copyCard: CopyProgressCard {
        CopyProgressCard(
            label: data.copyLabel,
            progress: data.copyProgress,
            progressText: data.copyProgressText,
            caption: data.copyCaption
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        weatherCard
                        loadCard
                    }

                    timerCard
                    copyCard
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
