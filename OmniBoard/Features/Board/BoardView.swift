import SwiftUI

struct BoardView: View {
    private let hourlyForecast: [(hour: String, temperature: String)] = [
        ("9", "20"),
        ("10", "22"),
        ("11", "21"),
        ("12", "19"),
    ]

    private let afternoonForecast: [(time: String, condition: String, temperature: String)] = [
        ("1 PM", "Sun", "23°"),
        ("2 PM", "Cloud", "22°"),
        ("3 PM", "Cloud", "21°"),
        ("4 PM", "Rain", "19°"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        currentWeatherSmallCard
                        highWeatherSmallCard
                    }

                    mediumForecastCard
                    largeForecastCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Board")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var currentWeatherSmallCard: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sun.max")
                    .font(.title2)
                    .foregroundStyle(.primary)

                Text("22°")
                    .font(.system(size: 34, weight: .bold))

                Text("Toronto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                StatusPill(title: "Fresh")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
    }

    private var highWeatherSmallCard: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "cloud")
                    .font(.title2)
                    .foregroundStyle(.primary)

                Text("19°")
                    .font(.system(size: 34, weight: .bold))

                Text("High 24")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
    }

    private var mediumForecastCard: some View {
        BoardCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Toronto")
                        .font(.title2.weight(.bold))

                    Text("Partly Cloudy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("22°")
                        .font(.system(size: 48, weight: .bold))
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 12) {
                    HStack(spacing: 20) {
                        ForEach(hourlyForecast, id: \.hour) { item in
                            Text(item.hour)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 20)
                        }
                    }

                    HStack(spacing: 20) {
                        ForEach(hourlyForecast, id: \.hour) { item in
                            Text(item.temperature)
                                .font(.subheadline.weight(.semibold))
                                .frame(minWidth: 20)
                        }
                    }
                }
            }
        }
    }

    private var largeForecastCard: some View {
        BoardCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This afternoon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("22°")
                        .font(.system(size: 34, weight: .bold))

                    Text("Partly cloudy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(afternoonForecast.enumerated()), id: \.offset) { index, row in
                        HStack {
                            Text(row.time)
                                .foregroundStyle(.secondary)

                            Text(row.condition)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(row.temperature)
                                .fontWeight(.semibold)
                        }
                        .font(.body)
                        .padding(.vertical, 12)

                        if index < afternoonForecast.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct BoardCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    BoardView()
}
