enum BoardScreenCopy {
    static func displayedStrings(from data: BoardSampleData = .preview) -> [String] {
        [
            data.temperature,
            data.location,
            data.weatherStatus,
            data.loadValue,
            data.loadLabel,
            data.opensInLabel,
            data.timerDisplay,
            data.timerExpiryCaption,
            data.copyLabel,
            data.copyProgressText,
            data.copyCaption,
        ]
    }
}
