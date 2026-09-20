struct BoardSampleData {
    static let widgets: [BoardWidgetItem] = [
        BoardWidgetItem(
            id: "metric-toronto",
            kind: .metric,
            size: .small,
            title: "Toronto",
            subtitle: "Temperature",
            value: "22°",
            status: "Fresh",
            progress: nil,
            presentation: nil
        ),
        BoardWidgetItem(
            id: "progress-load",
            kind: .progress,
            size: .small,
            title: "Load",
            subtitle: "circular",
            value: "72",
            status: nil,
            progress: 0.72,
            presentation: .circular
        ),
        BoardWidgetItem(
            id: "notice-weather-source",
            kind: .notice,
            size: .medium,
            title: "Weather source updated",
            subtitle: "Asked for the current temperature",
            value: "",
            status: "Fresh",
            progress: nil,
            presentation: nil
        ),
        BoardWidgetItem(
            id: "progress-copy",
            kind: .progress,
            size: .medium,
            title: "Copy",
            subtitle: "bar · On this iPhone",
            value: "62%",
            status: nil,
            progress: 0.62,
            presentation: .bar
        ),
        BoardWidgetItem(
            id: "countdown-meeting",
            kind: .countdown,
            size: .medium,
            title: "Meeting",
            subtitle: "Opens in",
            value: "12:40",
            status: "On this iPhone",
            progress: nil,
            presentation: nil
        ),
    ]
}
