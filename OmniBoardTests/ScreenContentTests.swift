import XCTest
@testable import OmniBoard

final class ScreenContentTests: XCTestCase {
    func testBoardShowsHardcodedWeatherStub() {
        let texts = ViewTextExtractor.texts(from: BoardView())
        let combined = texts.joined(separator: " ")

        XCTAssertTrue(
            combined.contains("Toronto"),
            "Board should show Toronto. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("22°"),
            "Board should show 22°. Found: \(combined)"
        )
    }

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
