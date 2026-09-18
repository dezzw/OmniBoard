struct BoardSampleData {
    let temperature: String
    let location: String
    let weatherStatus: String
    let loadProgress: Double
    let loadValue: String
    let loadLabel: String
    let opensInLabel: String
    let timerDisplay: String
    let timerExpiryCaption: String
    let copyLabel: String
    let copyProgress: Double
    let copyProgressText: String
    let copyCaption: String

    static let preview = BoardSampleData(
        temperature: "22°",
        location: "Toronto",
        weatherStatus: "Fresh",
        loadProgress: 0.72,
        loadValue: "72",
        loadLabel: "Load",
        opensInLabel: "Opens in",
        timerDisplay: "12:40",
        timerExpiryCaption: "Expires in 12m 40s · On this iPhone",
        copyLabel: "Copy",
        copyProgress: 0.62,
        copyProgressText: "62%",
        copyCaption: "On this iPhone"
    )
}
