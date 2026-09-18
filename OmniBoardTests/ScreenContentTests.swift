import XCTest
@testable import OmniBoard

final class ScreenContentTests: XCTestCase {
    @MainActor
    func testBoardShowsHardcodedWeatherStub() {
        let data = BoardSampleData.preview
        let combined = [
            ViewTextExtractor.texts(from: WeatherStubCard(
                temperature: data.temperature,
                location: data.location,
                status: data.weatherStatus
            )),
            ViewTextExtractor.texts(from: LoadProgressCard(
                progress: data.loadProgress,
                value: data.loadValue,
                label: data.loadLabel
            )),
            ViewTextExtractor.texts(from: TimerCard(
                opensInLabel: data.opensInLabel,
                time: data.timerDisplay,
                expiryCaption: data.timerExpiryCaption
            )),
            ViewTextExtractor.texts(from: CopyProgressCard(
                label: data.copyLabel,
                progress: data.copyProgress,
                progressText: data.copyProgressText,
                caption: data.copyCaption
            )),
        ]
        .flatMap { $0 }
        .joined(separator: " ")

        XCTAssertTrue(
            combined.contains("Toronto"),
            "Board should show Toronto. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("22°"),
            "Board should show 22°. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("72"),
            "Board should show load value 72. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Load"),
            "Board should show Load label. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Opens in"),
            "Board should show Opens in. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("12:40"),
            "Board should show 12:40. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Copy"),
            "Board should show Copy. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("62%"),
            "Board should show 62%. Found: \(combined)"
        )

        for expected in BoardScreenCopy.displayedStrings(from: data) {
            XCTAssertTrue(
                combined.contains(expected),
                "Board card content should include \(expected). Found: \(combined)"
            )
        }
    }

    @MainActor
    func testServiceShowsLocalStatusRows() {
        let texts = ViewTextExtractor.texts(from: ServiceView())
        let combined = texts.joined(separator: " ")

        XCTAssertTrue(
            combined.contains("Core"),
            "Service should show Core. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Weather"),
            "Service should show Weather. Found: \(combined)"
        )
    }

    @MainActor
    func testSettingsShowsGeneralPreferences() {
        let texts = ViewTextExtractor.texts(from: SettingsView())
        let combined = texts.joined(separator: " ")

        XCTAssertTrue(
            combined.contains("Appearance"),
            "Settings should show Appearance. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("System Blue"),
            "Settings should show System Blue. Found: \(combined)"
        )
    }
}
