enum BoardWidgetKind {
    case notice
    case metric
    case progress
    case countdown
}

enum BoardWidgetSize {
    case small
    case medium
    case large
}

enum BoardProgressPresentation {
    case circular
    case bar
}

struct BoardWidgetItem: Identifiable {
    let id: String
    let kind: BoardWidgetKind
    let size: BoardWidgetSize
    let title: String
    let subtitle: String
    let value: String
    let status: String?
    let progress: Double?
    let presentation: BoardProgressPresentation?

    var displayedTexts: [String] {
        var texts = [title, subtitle]
        if !value.isEmpty {
            texts.append(value)
        }
        if let status {
            texts.append(status)
        }
        return texts
    }
}
