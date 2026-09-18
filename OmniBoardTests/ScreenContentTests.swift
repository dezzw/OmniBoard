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
