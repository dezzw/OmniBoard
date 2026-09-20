import XCTest
@testable import OmniBoard

final class ScreenContentTests: XCTestCase {
    func testBoardShowsWidgetGridContent() {
        let board = BoardView()
        let combined = board.displayedTexts.joined(separator: " ")

        XCTAssertTrue(
            combined.contains("Toronto"),
            "Board should show Toronto. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("22°"),
            "Board should show 22°. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Load"),
            "Board should show Load. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("72"),
            "Board should show load value 72. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Weather source updated"),
            "Board should show notice title. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Asked for the current temperature"),
            "Board should show notice subtitle. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Copy"),
            "Board should show Copy. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("62%"),
            "Board should show 62%. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Meeting"),
            "Board should show Meeting. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("Opens in"),
            "Board should show Opens in. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("12:40"),
            "Board should show 12:40. Found: \(combined)"
        )

        let kinds = Set(BoardSampleData.widgets.map { widgetKindName($0.kind) })
        XCTAssertEqual(kinds, Set(["notice", "metric", "progress", "countdown"]))
    }

    func testServiceShowsLocalStatusRows() {
        let combined = ServiceView().displayedTexts.joined(separator: " ")

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
        let combined = SettingsView().displayedTexts.joined(separator: " ")

        XCTAssertTrue(
            combined.contains("Appearance"),
            "Settings should show Appearance. Found: \(combined)"
        )
        XCTAssertTrue(
            combined.contains("System Blue"),
            "Settings should show System Blue. Found: \(combined)"
        )
    }

    private func widgetKindName(_ kind: BoardWidgetKind) -> String {
        switch kind {
        case .notice: "notice"
        case .metric: "metric"
        case .progress: "progress"
        case .countdown: "countdown"
        }
    }
}
